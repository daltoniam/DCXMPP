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
static NSString const *XMLNS_ROSTER  = @"jabber:iq:roster";
static NSString const *XMLNS_DISCO  = @"http://jabber.org/protocol/disco#info";

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
 Received the roster.
 @param users returns the roster users.
 */
-(void)didReceiveRoster:(NSArray*)users;

/**
 Received the bookmarks.
 */
-(void)didReceiveBookmarks;


///-------------------------------
/// @name Messaging Delegate Methods
///-------------------------------

/**
 Received a message.
 @param message is the text of the message.
 @param user is who the message was from
 */
-(void)didReceiveMessage:(NSString*)message from:(DCXMPPUser*)user attributes:(NSDictionary*)attributes;

/**
 Received a message.
 @param message is the text of the message.
 @param group is what group the message was from
 @param user is who the message was from
 */
-(void)didReceiveGroupMessage:(NSString*)message group:(DCXMPPGroup*)group from:(DCXMPPUser*)user attributes:(NSDictionary*)attributes;

/**
 Received a message that is from the current user, probably from another client
 @param message is the text of the message.
 @param group is what group the message was from
 @param user is who the message was from. This would be the current user
 */
-(void)didReceiveGroupCarbon:(NSString*)message group:(DCXMPPGroup*)group from:(DCXMPPUser*)user attributes:(NSDictionary*)attributes;

/**
 Received a message.
 @param state is the state of typing that was Received.
 @param user is who the message was from
 */
-(void)didReceiveTypingState:(DCTypingState)state from:(DCXMPPUser*)user;

/**
 Received a message.
 @param state is the state of typing that was Received.
@param group is what group the message was from
 @param user is who the message was from
 */
-(void)didReceiveGroupTypingState:(DCTypingState)state group:(DCXMPPGroup*)group from:(DCXMPPUser*)user;

/**
 Notifies when a user joined a group.
 @param group is what group the message was from
 @param user is who joined the room
 */
-(void)userDidJoinGroup:(DCXMPPGroup*)group user:(DCXMPPUser*)user;

/**
 Notifies when a user leaves a group.
 @param group is what group the message was from
 @param user is who left the room
 */
-(void)userDidLeaveGroup:(DCXMPPGroup*)group user:(DCXMPPUser*)user;

///-------------------------------
/// @name User Delegate Methods
///-------------------------------

/**
 Received a updated vcard for a user.
 @param user is who the vcard that was updated
 */
-(void)didUpdateVCard:(DCXMPPUser*)user;

/**
 Received a updated vcard for a user.
 @param user is who the vcard that was updated
 */
-(void)didUpdatePresence:(DCXMPPUser*)user;

/**
 Received a buddy request from a user.
 @param user who requested your friendship
 */
-(void)didReceiveBuddyRequest:(DCXMPPUser*)user;

/**
 A buddy was accepted.
 @param user who accepted your buddy request/
 */
-(void)buddyDidAccept:(DCXMPPUser*)user;

/**
 A buddy removed you.
 @param user who remove you as a buddy.
 */
-(void)buddyDidRemove:(DCXMPPUser*)user;

/**
 Someone invited you to a group
 @param group you where invited to.
 */
-(void)didReceiveGroupInvite:(DCXMPPGroup*)group from:(DCXMPPUser*)user;

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
 Implement this to Received the delegate methods.
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
 returns the pending buddies, if you have pending requests.
 */
@property(nonatomic,strong)NSMutableArray *pendingBuddies;

/**
 returns the pending groups, if you have pending requests.
 */
@property(nonatomic,strong)NSMutableArray *pendingGroups;

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
 Disconnect and terminate communication from the xmpp server.
 */
-(void)disconnect;

/**
 Queues and sends an arbitrary stanza.
 @param The XMLElement stanza to send.
 */
-(void)sendStanza:(XMLElement*)element;

/**
 Queues and sends a message to the user jid.
 @param text is the text string to send.
 @param The jid is the jid string of the user to send to.
 */
-(NSString*)sendMessage:(NSString *)text jid:(NSString*)jid;

/**
 Queues and sends a typing state to the user jid.
 @param state is the state option to send.
 @param The jid is the jid string of the user to send to.
 */
-(void)sendTypingState:(DCTypingState)state jid:(NSString*)jid;

/**
 Find a DCXMPPUser for a jid
 @param The jid is the jid string of the user to find.
 */
-(DCXMPPUser*)userForJid:(NSString*)jid;

/**
 Find a DCXMPPGroup for a jid
 @param The jid is the jid string of the group to find.
 */
-(DCXMPPGroup*)groupForJid:(NSString*)jid;

/**
 Custom use. Adds a group object to the list of groups.
 @param DCXMPPGroup to add.
 */
-(void)addGroup:(DCXMPPGroup*)group;

/**
 Custom use. Adds a user object to the list of users.
 @param DCXMPPUser to add.
 */
-(void)addUser:(DCXMPPUser*)user;


/**
 Set the presence of the current user.
 @param presence: presence type you want to set
 @param status: status message you want to set.
 */
-(void)setPresence:(DCUserPresence)presence status:(NSString*)status;

/**
 Add a cookie to send in the request headers of your requests.
 @param cookie: http cookie to add.
 */
-(void)addCookie:(NSHTTPCookie*)cookie;

/**
 Request to add a new user to the current user roster
 @param jidString: a string of a bare jid of a buddy to add
 */
-(void)addBuddy:(NSString*)jidString;

/**
 Request to remove a user from the current user roster
 @param jidString: a string of a bare jid of a buddy to remove
 */
-(void)removeBuddy:(NSString*)jidString;

/**
 background support for iOS.
 */
-(void)background;

/**
 foreground support for iOS.
 */
-(void)foreground;


@end
