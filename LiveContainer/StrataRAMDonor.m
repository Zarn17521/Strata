#import "StrataRAMDonor.h"
#import <os/proc.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <malloc/malloc.h>
#import <unistd.h>

@implementation StrataRAMDonorResult
@end

@implementation StrataRAMDonor {
    NSMutableArray<NSData *> *_allocations;
}

+ (instancetype)shared {
    static StrataRAMDonor *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [StrataRAMDonor new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _allocations = [NSMutableArray new];
    }
    return self;
}

- (uint64_t)physicalRAM {
    int mib[] = {CTL_HW, HW_MEMSIZE};
    uint64_t size = 0;
    size_t len = sizeof(size);
    sysctl(mib, 2, &size, &len, NULL, 0);
    return size;
}

- (uint64_t)osAvailable {
    return os_proc_available_memory();
}

- (uint64_t)physFootprint {
    task_vm_info_data_t info = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) == KERN_SUCCESS) {
        return info.phys_footprint;
    }
    return 0;
}

- (StrataRAMDonorResult *)runCeilingTestWithTargetMB:(NSUInteger)targetMB {
    return [self runDonorTestWithTargetMB:targetMB donorCount:1];
}

- (StrataRAMDonorResult *)runDonorTestWithTargetMB:(NSUInteger)targetMB donorCount:(NSUInteger)donorCount {
    @synchronized (self) {
        StrataRAMDonorResult *result = [StrataRAMDonorResult new];
        result.physicalRAM = [self physicalRAM];
        result.osAvailable = [self osAvailable];
        NSMutableString *log = [NSMutableString stringWithString:@"Local allocation diagnostic; no cross-process donor or bypass.\n"];
        NSMutableArray<NSData *> *blocks = [NSMutableArray new];
        const size_t reserve = 768ULL * 1024 * 1024;
        const size_t page = (size_t)getpagesize();
        const size_t target = MIN(targetMB, 2048UL) * 1024ULL * 1024ULL;
        size_t allocated = 0;
        uint64_t peak = [self physFootprint];
        while (allocated < target) {
            size_t chunk = MIN(16ULL * 1024 * 1024, target - allocated);
            if ([self osAvailable] < reserve + chunk) {
                [log appendString:@"Stopped at reserved headroom.\n"];
                break;
            }
            void *ptr = malloc(chunk);
            if (!ptr) { [log appendString:@"Allocation failed.\n"]; break; }
            volatile uint8_t *bytes = ptr;
            for (size_t k = 0; k < chunk; k += page) bytes[k] = (uint8_t)((allocated + k) / page);
            for (size_t k = 0; k < chunk; k += page) {
                if (bytes[k] != (uint8_t)((allocated + k) / page)) result.mismatches++;
                result.pagesVerified++;
            }
            [blocks addObject:[NSData dataWithBytesNoCopy:ptr length:chunk freeWhenDone:YES]];
            allocated += chunk;
            peak = MAX(peak, [self physFootprint]);
            if (result.mismatches) break;
        }
        result.physFootprint = peak;
        result.pooledTouched = allocated;
        result.liveDonors = 0;
        result.exceedsLimit = NO;
        [blocks removeAllObjects];
        malloc_zone_pressure_relief(NULL, 0);
        [log appendFormat:@"Touched: %zu MiB; requested groups: %lu; peak: %llu MiB. Allocations released. No bypass established.\n", allocated / (1024*1024), (unsigned long)donorCount, (unsigned long long)(peak / (1024*1024))];
        result.log = log;
        return result;
    }
}

- (void)releaseAll {
    @synchronized (self) {
        [_allocations removeAllObjects];
        malloc_zone_pressure_relief(NULL, 0);
    }
}

- (NSDictionary *)currentStats {
    return @{
        @"physicalRAM": @([self physicalRAM]),
        @"osAvailable": @([self osAvailable]),
        @"physFootprint": @([self physFootprint]),
        @"allocations": @(_allocations.count)
    };
}

@end
