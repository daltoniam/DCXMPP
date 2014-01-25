////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  BoshRequest.h
//
//  Created by Dalton Cherry on 10/31/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>
#import "XMLKit.h"

@class BoshRequest;

@protocol BoshRequestDelegate <NSObject>

@required
/**
 Returns when the request has finished.
 @param the request that failed.
 */
-(void)requestFinished:(BoshRequest*)request;

/**
 Returns when the request has failed.
 @param the request that failed.
 */
-(void)requestFailed:(BoshRequest*)request;

@end

@interface BoshRequest : NSObject

/**
 Assign this to implement the BoshRequest delegate methods.
 */
@property(nonatomic,assign)id<BoshRequestDelegate>delegate;

/**
 Assign this to implement the BoshRequest delegate methods.
 */
@property(nonatomic,assign)BOOL isEmpty;

/**
 initializes and returns a new BoshRequest.
 @param request is the NSURLRequest you created.
 */
-(instancetype)initWithRequest:(NSURLRequest*)request;

/**
 starts the BOSH request.
 */
-(void)start;

/**
 stops the BOSH request.
 */
-(void)cancel;

/**
 This request a XMLElement object from the responseData of the request.
 @return an XMLElement object.
 */
-(XMLElement*)responseElement;

@end
