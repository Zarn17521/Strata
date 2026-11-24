#import "StrataProcessMemory.h"
#import <os/proc.h>
#import <mach/mach.h>
#import <Security/Security.h>
#import <unistd.h>
#import <sys/sysctl.h>
#import <TargetConditionals.h>

#if !TARGET_OS_OSX
extern void *SecTaskCreateFromSelf(CFAllocatorRef allocator);
extern CFTypeRef SecTaskCopyValueForEntitlement(void *task, CFStringRef key, CFErrorRef *error);
#endif

// Capture the real process identity before the guest runtime replaces bundle/home metadata.
// Samples contain no pairing data, account identifiers, paths, or game contents.
void StrataStartProcessMemoryDiagnostics(NSString *group, NSString *guestName, NSString *executionMode) {
    NSURL *root = group.length ? [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:group] : nil;
    if (!root) return;
    NSURL *directory = [root URLByAppendingPathComponent:@"Library/StrataDiagnostics" isDirectory:YES];
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil]) return;
    void *task = SecTaskCreateFromSelf(NULL);
    CFTypeRef value = task ? SecTaskCopyValueForEntitlement(task, CFSTR("com.apple.developer.kernel.increased-memory-limit"), NULL) : NULL;
    BOOL increased = value && CFEqual(value, kCFBooleanTrue);
    if (value) CFRelease(value);
    if (task) CFRelease(task);
    const pid_t pid = getpid();
    NSString *name = guestName.lastPathComponent ?: @"Guest";
    NSURL *latest = [directory URLByAppendingPathComponent:@"guest-memory.json"];
    NSURL *byPID = [directory URLByAppendingPathComponent:[NSString stringWithFormat:@"%d-memory.json", pid]];
    NSTimeInterval startedAt = NSDate.date.timeIntervalSince1970;
    __block uint64_t peakFootprint = 0;
    __block uint64_t minimumAvailable = UINT64_MAX;
    void (^sample)(void) = ^{
        @autoreleasepool {
            task_vm_info_data_t vm = {0};
            mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
            BOOL hasFootprint = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vm, &count) == KERN_SUCCESS;
#if TARGET_OS_OSX
            uint64_t available = 0; // iOS headroom API is unavailable on native macOS.
#else
            uint64_t available = os_proc_available_memory();
#endif
            struct kinfo_proc process = {0}; size_t processSize = sizeof(process); int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
            BOOL attached = sysctl(mib, 4, &process, &processSize, NULL, 0) == 0 && (process.kp_proc.p_flag & P_TRACED);
            NSMutableDictionary *record = [@{@"schema":@1, @"pid":@(pid), @"guest":name, @"executionMode":executionMode ?: @"unknown",
                @"startedAt":@(startedAt), @"sampledAt":@(NSDate.date.timeIntervalSince1970),
                @"increasedMemoryEntitlement":@(increased), @"debuggerAttached":@(attached), @"availableBytes":@(available),
                @"availableReported":@(available > 0), @"footprintReported":@(hasFootprint)} mutableCopy];
            if (hasFootprint) {
                peakFootprint = MAX(peakFootprint, vm.phys_footprint);
                record[@"footprintBytes"] = @(vm.phys_footprint);
                record[@"peakFootprintBytes"] = @(peakFootprint);
            }
#if !TARGET_OS_OSX
            minimumAvailable = MIN(minimumAvailable, available);
            record[@"minimumAvailableBytes"] = @(minimumAvailable);
#endif
            record[@"sessionSeconds"] = @(MAX(0, NSDate.date.timeIntervalSince1970 - startedAt));
            record[@"thermalState"] = @(NSProcessInfo.processInfo.thermalState);
            NSData *json = [NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingPrettyPrinted error:nil];
            [json writeToURL:byPID options:NSDataWritingAtomic error:nil];
            [json writeToURL:latest options:NSDataWritingAtomic error:nil];
        }
    };
    sample();
    static dispatch_source_t timer;
    if (timer) dispatch_source_cancel(timer);
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), 10 * NSEC_PER_SEC, 2 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, sample);
    dispatch_resume(timer);
}

// Live memory overlay: every Strata process (Strata, apps in their own process, helper/donor processes)
// writes its footprint and limit once a second while the overlay is enabled.
void StrataStartMemoryOverlaySampler(NSString *group, NSString *role, NSString *name) {
    static dispatch_source_t timer;
    static NSString *currentRole, *currentName;
    static NSUserDefaults *settings;
    static NSURL *file;
    @synchronized ([NSProcessInfo class]) { currentRole = [role copy]; currentName = [name copy]; }
    if (timer || !group) return;
    NSURL *root = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:group];
    if (!root) return;
    NSURL *directory = [root URLByAppendingPathComponent:@"Library/StrataDiagnostics/Live" isDirectory:YES];
    file = [directory URLByAppendingPathComponent:[NSString stringWithFormat:@"proc-%d.json", getpid()]];
    settings = [[NSUserDefaults alloc] initWithSuiteName:group];
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, NSEC_PER_SEC / 5);
    __block BOOL sampleFileMayExist = YES;
    __block BOOL directoryReady = NO;
    dispatch_source_set_event_handler(timer, ^{
        @autoreleasepool {
        if (![settings boolForKey:@"StrataMemoryOverlay"]) {
            // Remove a stale sample only once, not once per second forever.
            if (sampleFileMayExist) {
                [NSFileManager.defaultManager removeItemAtURL:file error:nil];
                sampleFileMayExist = NO;
            }
            directoryReady = NO;
            return;
        }
        task_vm_info_data_t vm = {0};
        mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
        if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vm, &count) != KERN_SUCCESS) return;
        NSString *r, *n;
        @synchronized ([NSProcessInfo class]) { r = currentRole ?: @"process"; n = currentName ?: @""; }
        NSDictionary *sample = @{@"pid": @(getpid()), @"role": r, @"name": n, @"footprint": @(vm.phys_footprint),
                                 @"available": @(os_proc_available_memory()), @"time": @(NSDate.date.timeIntervalSince1970)};
        if (!directoryReady)
            directoryReady = [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
        if (directoryReady) {
            NSData *data=[NSJSONSerialization dataWithJSONObject:sample options:0 error:nil];
            if ([data writeToURL:file atomically:YES]) sampleFileMayExist = YES;
            else directoryReady = NO;
        }
        }
    });
    dispatch_resume(timer);
}
