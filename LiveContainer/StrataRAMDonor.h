#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StrataRAMDonorResult : NSObject
@property (nonatomic) uint64_t physicalRAM;
@property (nonatomic) uint64_t osAvailable;
@property (nonatomic) uint64_t physFootprint;
@property (nonatomic) uint64_t pooledTouched;
@property (nonatomic) NSInteger liveDonors;
@property (nonatomic) uint64_t pagesVerified;
@property (nonatomic) uint64_t mismatches;
@property (nonatomic) BOOL exceedsLimit;
@property (nonatomic, copy) NSString *log;
@end

@interface StrataRAMDonor : NSObject

+ (instancetype)shared;

- (StrataRAMDonorResult *)runCeilingTestWithTargetMB:(NSUInteger)targetMB;
- (StrataRAMDonorResult *)runDonorTestWithTargetMB:(NSUInteger)targetMB donorCount:(NSUInteger)donorCount;
- (void)releaseAll;
- (NSDictionary *)currentStats;

@end

NS_ASSUME_NONNULL_END
