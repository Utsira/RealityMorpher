//
//  Constants.h
//  MorphTargetExample
//
//  Created by Oliver Dew on 10/08/2023.
//

#ifndef Constants_h
#define Constants_h

#ifdef __METAL_VERSION__

#define NS_CLOSED_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

typedef NS_CLOSED_ENUM(NSInteger, MorpherConstant) {
	MorpherConstantMaxTargetCount = 3,
};

#endif /* Constants_h */
