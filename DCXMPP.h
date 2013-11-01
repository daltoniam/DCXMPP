////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DCXMPP.h
//
//  Created by Dalton Cherry on 10/31/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>

@interface DCXMPP : NSObject

@property(nonatomic,assign,readonly)BOOL isConnected;
/**
This returns a DCXMPP singlton that you use to do all your xmpp needs.
 @return DCXMPP singlton object.
 */
+(instancetype)manager;

/**
 The connect method that starts the xmpp handshake over BOSH.
 @param userName is the username you want to login with.
 @param password is the password of the username.
 @param server is the server to connect to.
 @param port is the port to connect over to the xmpp server for the BOSH server.
 @param host is your host domain.
 @param boshURL is the boshURL to connect to.
 */
-(void)connect:(NSString*)userName password:(NSString*)password host:(NSString*)host boshURL:(NSString*)boshURL;

@end
