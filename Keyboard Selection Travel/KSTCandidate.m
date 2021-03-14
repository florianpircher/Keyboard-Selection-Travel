//
//  KSTCandidate.m
//  Keyboard Selection Travel
//
//  Created by Florian Pircher on 2021-03-13.
//

#import "KSTCandidate.h"

@implementation KSTCandidate
@synthesize distance;
@synthesize element;

- (NSString *)description
{
    return [self debugDescription];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> %f", [self class], self, distance];
}
@end
