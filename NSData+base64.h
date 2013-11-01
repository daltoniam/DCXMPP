////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  NSData+base64.h
//
//  Created by Dalton Cherry on 10/31/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>

@interface NSData (base64)

/**
 Returns a base64 encoded NSString from the NSData.
 @return A NSString object that is base64.
 */
-(NSString*)base64String;

/**
 Returns a new NSData object that has its data base64 decoded.
 @return NSData object with data base64 decoded.
 */
-(NSData*)base64Decoded;

@end
