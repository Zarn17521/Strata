#import "StrataRAMDonor.h"
#import <os/proc.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import <mach/vm_map.h>

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
    StrataRAMDonorResult *result = [StrataRAMDonorResult new];
    result.physicalRAM = [self physicalRAM];
    result.osAvailable = [self osAvailable];
    
    NSMutableString *log = [NSMutableString new];
    [log appendFormat:@"=== Ceiling Test ===\nTarget: %lu MB\n", (unsigned long)targetMB];
    
    size_t pageSize = getpagesize();
    size_t chunkSize = 64 * 1024 * 1024;
    size_t targetBytes = targetMB * 1024ULL * 1024ULL;
    size_t allocated = 0;
    uint64_t mismatches = 0;
    
    while (allocated < targetBytes) {
        size_t thisChunk = MIN(chunkSize, targetBytes - allocated);
        void *ptr = malloc(thisChunk);
        if (!ptr) {
            [log appendFormat:@"malloc failed at %zu MB\n", allocated / (1024*1024)];
            break;
        }
        
        for (size_t i = 0; i < thisChunk; i += pageSize) {
            ((volatile char *)ptr)[i] = (char)(i & 0xFF);
        }
        
        for (size_t i = 0; i < thisChunk; i += pageSize) {
            if (((volatile char *)ptr)[i] != (char)(i & 0xFF)) {
                mismatches++;
            }
        }
        
        [_allocations addObject:[NSData dataWithBytesNoCopy:ptr length:thisChunk freeWhenDone:YES]];
        allocated += thisChunk;
        
        [log appendFormat:@"Allocated + touched: %zu MB | Footprint: %.1f MB\n",
             allocated / (1024*1024), [self physFootprint] / (1024.0*1024.0)];
    }
    
    result.physFootprint = [self physFootprint];
    result.pooledTouched = allocated;
    result.pagesVerified = allocated / pageSize;
    result.mismatches = mismatches;
    result.exceedsLimit = (result.physFootprint > result.osAvailable);
    result.log = log;
    
    return result;
}

- (StrataRAMDonorResult *)runDonorTestWithTargetMB:(NSUInteger)targetMB donorCount:(NSUInteger)donorCount {
    StrataRAMDonorResult *result = [StrataRAMDonorResult new];
    result.physicalRAM = [self physicalRAM];
    result.osAvailable = [self osAvailable];
    
    NSMutableString *log = [NSMutableString new];
    [log appendFormat:@"=== Donor Test ===\nTarget: %lu MB | Donors: %lu\n", (unsigned long)targetMB, (unsigned long)donorCount];
    
    size_t pageSize = getpagesize();
    size_t perDonor = (targetMB * 1024ULL * 1024ULL) / MAX(donorCount, 1);
    size_t totalAllocated = 0;
    uint64_t mismatches = 0;
    
    for (NSUInteger d = 0; d < donorCount; d++) {
        void *ptr = NULL;
        kern_return_t kr = vm_allocate(mach_task_self(), (vm_address_t *)&ptr, perDonor, VM_FLAGS_ANYWHERE);
        
        if (kr != KERN_SUCCESS || !ptr) {
            ptr = malloc(perDonor);
            if (!ptr) {
                [log appendFormat:@"Donor %lu failed to allocate\n", (unsigned long)d];
                continue;
            }
        }
        
        for (size_t i = 0; i < perDonor; i += pageSize) {
            ((volatile char *)ptr)[i] = (char)((d + i) & 0xFF);
        }
        
        for (size_t i = 0; i < perDonor; i += pageSize) {
            if (((volatile char *)ptr)[i] != (char)((d + i) & 0xFF)) {
                mismatches++;
            }
        }
        
        [_allocations addObject:[NSData dataWithBytesNoCopy:ptr length:perDonor freeWhenDone:YES]];
        totalAllocated += perDonor;
        
        [log appendFormat:@"Donor %lu: +%zu MB | Total pooled: %zu MB\n",
             (unsigned long)d, perDonor/(1024*1024), totalAllocated/(1024*1024)];
    }
    
    result.physFootprint = [self physFootprint];
    result.pooledTouched = totalAllocated;
    result.liveDonors = (NSInteger)donorCount;
    result.pagesVerified = totalAllocated / pageSize;
    result.mismatches = mismatches;
    result.exceedsLimit = (result.pooledTouched > result.osAvailable) || (result.physFootprint > result.osAvailable * 0.9);
    
    [log appendFormat:@"\nResult: %@\n", result.exceedsLimit ? @"EXCEEDS LIMIT, bypass works" : @"Within normal limit"];
    result.log = log;
    
    return result;
}

- (void)releaseAll {
    [_allocations removeAllObjects];
    malloc_zone_pressure_relief(NULL, 0);
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
