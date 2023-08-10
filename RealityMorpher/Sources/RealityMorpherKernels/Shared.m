//
//  Shared.m
//  MorphTargetExample
//
//  Created by Oliver Dew on 10/08/2023.
//

#import <Foundation/Foundation.h>
#import "Shared.h"

@implementation NSBundle (NSBundleKernelsModule)
+ (NSBundle*) kernelsModule {
	return SWIFTPM_MODULE_BUNDLE;
}
@end
