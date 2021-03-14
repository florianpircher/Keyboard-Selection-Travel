//
//  KSTCandidate.h
//  Keyboard Selection Travel
//
//  Created by Florian Pircher on 2021-03-13.
//

#import <Foundation/Foundation.h>
#import <GlyphsCore/GSElement.h>

NS_ASSUME_NONNULL_BEGIN

@interface KSTCandidate : NSObject
@property CGFloat distance;
@property (weak) GSElement * _Nullable element;
@end

NS_ASSUME_NONNULL_END
