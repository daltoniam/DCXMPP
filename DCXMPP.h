////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DCXMPP.h
//
//  Created by Dalton Cherry on 10/31/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>
#import "DCXMPPUser.h"
#import "XMLKit.h"

//our xmlns protocols
static NSString const *XMLNS_BOSH = @"http://jabber.org/protocol/httpbind";
static NSString const *XMLNS_CHAT_STATE = @"http://jabber.org/protocol/chatstates";
static NSString const *XMLNS_BIND = @"urn:ietf:params:xml:ns:xmpp-bind";
static NSString const *XMLNS_CLIENT  = @"jabber:client";
static NSString const *XMLNS_SESSION = @"urn:ietf:params:xml:ns:xmpp-session";
static NSString const *XMLNS_MUC = @"http://jabber.org/protocol/muc";
static NSString const *XMLNS_VCARD  = @"vcard-temp";

@protocol DCXMPPDelegate <NSObject>

/**
 Did successfully authenicate.
 */
-(void)didXMPPConnect;

/**
 Failed to authenicate.
 */
-(void)didFailXMPPLogin;

/**
 Recieved the roster.
 @param users returns the roster users.
 */
-(void)didRecieveRoster:(NSArray*)users;

/**
 Recieved the bookmarks.
 */
-(void)didRecieveBookmarks;


///-------------------------------
/// @name Messaging Delegate Methods
///-------------------------------

/**
 Recieved a message.
 @param message is the text of the message.
 @param user is who the message was from
 */
-(void)didRecieveMessage:(NSString*)message from:(DCXMPPUser*)user;

/**
 Recieved a message.
 @param message is the text of the message.
 @param group is what group the message was from
 @param user is who the message was from
 */
-(void)didRecieveGroupMessage:(NSString*)message group:(DCXMPPGroup*)group from:(DCXMPPUser*)user;

/**
 Recieved a message that is from the current user, probably from another client
 @param message is the text of the message.
 @param group is what group the message was from
 @param user is who the message was from. This would be the current user
 */
-(void)didRecieveGroupCarbon:(NSString*)message group:(DCXMPPGroup*)group from:(DCXMPPUser*)user;

/**
 Recieved a message.
 @param state is the state of typing that was recieved.
 @param user is who the message was from
 */
-(void)didRecieveTypingState:(DCTypingState)state from:(DCXMPPUser*)user;

/**
 Recieved a message.
 @param state is the state of typing that was recieved.
@param group is what group the message was from
 @param user is who the message was from
 */
-(void)didRecieveGroupTypingState:(DCTypingState)state group:(DCXMPPGroup*)group from:(DCXMPPUser*)user;

///-------------------------------
/// @name User Delegate Methods
///-------------------------------

/**
 Recieved a updated vcard for a user.
 @param user is who the vcard that was updated
 */
-(void)didUpdateVCard:(DCXMPPUser*)user;

/**
 Recieved a updated vcard for a user.
 @param user is who the vcard that was updated
 */
-(void)didUpdatePresence:(DCXMPPUser*)user;

@end


@interface DCXMPP : NSObject

/**
 This returns the current bosh RID.
 @return long long value of the boshRID
 */
@property(nonatomic,assign,readonly)long long currentBoshRID;

/**
 This returns the current bosh SID.
 @return String value of the boshSID
 */
@property(nonatomic,copy,readonly)NSString *currentBoshSID;

/**
 This returns if we are connected to the server or not.
 @return YES if connected.
 */
@property(nonatomic,assign,readonly)BOOL isConnected;

/**
 Implement this to recieved the delegate methods.
 */
@property(nonatomic,assign)id<DCXMPPDelegate>delegate;

/**
 This returns the user you connected to the stream as.
 @return A DCXMPPUser of the current user.
 */
@property(nonatomic,strong,readonly)DCXMPPUser *currentUser;

/**
 This returns the current user's roster filled with DCXMPPUser objects. 
 @return A NSArray of the current user's roster.
 */
@property(nonatomic,strong,readonly)NSArray *roster;

/**
This returns a DCXMPP singlton that you use to do all your xmpp needs.
 @return DCXMPP singlton object.
 */
+(instancetype)manager;

/**
 The connect method that starts the xmpp handshake over BOSH.
 @param userName is the username you want to login with.
 @param password is the password of the username.
 @param host is your host domain.
 @param boshURL is the boshURL to connect to.
 */
-(void)connect:(NSString*)userName password:(NSString*)password host:(NSString*)host boshURL:(NSString*)boshURL;

/**
 The connect method is used for a custom persistence option.
 @param jid is the jid that was saved.
 @param rid is the rid that was saved.
 @param host is your host domain.
 @param boshURL is the boshURL to connect to.
 */
-(void)connect:(NSString*)jid rid:(long long)rid sid:(NSString*)sid host:(NSString*)host boshURL:(NSString*)boshURL;


/**
 Queues and sends an arbitrary stanza.
 @param The XMLElement stanza to send.
 */
-(void)sendStanza:(XMLElement*)element;

/**
 Queues and sends an message to the user jid.
 @param text is the text string to send.
 @param The jid is the jid string of the user to send to.
 */
-(void)sendMessage:(NSString *)text jid:(NSString*)jid;

@end
