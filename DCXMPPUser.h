////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DCXMPPUser.h
//
//  Created by Dalton Cherry on 11/1/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>

typedef enum {
    DCUserPresenceUnAvailable,
    DCUserPresenceAvailable,
    DCUserPresenceAway,
    DCUserPresenceBusy
} DCUserPresence;

typedef enum {
    DCTypingActive,
    DCTypingInActive,
    DCTypingGone,
    DCTypingComposing,
    DCTypingPaused
} DCTypingState;

typedef enum {
    DCGroupRoleMember,
    DCGroupRoleOwner
} DCGroupRole;
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface DCXMPPJID : NSObject

/**
 This returns a full user jid. (e.g. user@domain.com/resource)
 @return A full user JID string.
 */
@property(nonatomic,copy)NSString *fullJID;

/**
 This returns a bare user jid. (e.g. user@domain.com)
 @return A bare user JID string.
 */
@property(nonatomic,copy,readonly)NSString *bareJID;

/**
 This returns the resource of the user jid. (e.g. resource)
 @return The resource of the user JID string.
 */
@property(nonatomic,copy,readonly)NSString *resource;

/**
 This returns the host of user jid. (e.g. domain.com)
 @return The host user JID string.
 */
@property(nonatomic,copy,readonly)NSString *host;

/**
 This returns the name of user jid. (e.g. user)
 @return The name of the user JID string.
 */
@property(nonatomic,copy,readonly)NSString *name;

/**
 This initializes and returns a DCXMPPJID object.
 @param jid is the string representation of the jid.
 @return A new DCXMPPJID object.
 */
-(instancetype)initWithJID:(NSString*)jid;

/**
 This initializes and returns a DCXMPPJID object.
 @param jid is the string representation of the jid.
 @return A new DCXMPPJID object.
 */
+(DCXMPPJID*)jidWithString:(NSString*)jid;

@end
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface DCXMPPUser : NSObject

///-------------------------------
/// @name Standard Properties
///-------------------------------
/**
 This returns the name or 'nickname' of the user.
 @return The name of the user.
 */
@property(nonatomic,copy)NSString *name;

/**
 This returns the 'nickname' of the user from the vcard.
 @return The vcard nickname of the user.
 */
@property(nonatomic,copy)NSString *nickname;

/**
 This returns the image hash of the user.
 @return The image hash of the user.
 */
@property(nonatomic,copy)NSString *imageHash;

/**
 This returns the avatar (vcard image) of the user.
 @return The avatar of the user.
 */
@property(nonatomic,strong)NSData *avatarData;

/**
 This returns the jid object of the user
 @return The jid of the user.
 */
@property(nonatomic,strong)DCXMPPJID *jid;

/**
 This returns the current presence of the user (avaliable,away,busy,etc).
 @return The name of the user.
 */
@property(nonatomic,assign)DCUserPresence presence;

/**
 This returns the status message of the user.
 @return The status of the user.
 */
@property(nonatomic,copy)NSString *status;

/**
 This returns if this is the current user.
 @return The the current user.
 */
@property(nonatomic,assign)BOOL isCurrentUser;

/**
 The last resource is the client we talked.
 @return The the last client resource we chatted with.
 */
@property(nonatomic,copy)NSString *lastResource;

/**
 This initializes and returns a DCXMPPUser object.
 @param jid is the string representation of the jid.
 @return A new DCXMPPUser object.
 */
-(instancetype)initWithJID:(NSString*)jid;


///-------------------------------
/// @name User Interaction
///-------------------------------

/**
 This sends a message to the user. XEP-0022
 @param the text of the message you want to send.
 */
-(NSString*)sendMessage:(NSString*)text;


/**
 This sends a typing state message to the user. XEP-0085.
 @param the state message you want to send.
 */
-(void)sendTypingState:(DCTypingState)state;

/**
 This sends a request for this user's vCard.
 */
-(void)getVCard;

/**
 This sends a request for this user's Presence.
 */
-(void)getPresence;

///-------------------------------
/// @name Factory Methods
///-------------------------------
/**
 This initializes and returns a DCXMPPUser object.
 @param jid is the string representation of the jid.
 @return A new DCXMPPUser object.
 */
+(DCXMPPUser*)userWithJID:(NSString*)jid;

@end
////////////////////////////////////////////////////////////////////////////////////////////////////
//XEP-0045.
////////////////////////////////////////////////////////////////////////////////////////////////////

@class DCXMPPGroupUser;

@interface DCXMPPGroup : DCXMPPUser

/**
 This returns if this group is currently joined or not.
 @return if the group is joined or not.
 */
@property(nonatomic,assign,readonly)BOOL isJoined;

/**
 This returns if this group is currently joined or not.
 @param user is the user object to add to the group.
 @param role is the role the user has in the group.
 */
-(void)addUser:(DCXMPPUser*)user role:(DCGroupRole)role;

/**
 Remove a user from a group.
 @param remove a user from the group.
 */
-(void)removeUser:(DCXMPPUser*)user;

/**
 This returns a DCXMPPGroupUser object by searching for a user.
 @param user is the user object to find in the group.
 */
-(DCXMPPGroupUser*)findUser:(DCXMPPUser*)user;


/**
 This initializes and returns a DCXMPPGroup object.
 @param jid is the string representation of the jid.
 @return A new DCXMPPGroup object.
 */
+(DCXMPPGroup*)groupWithJID:(NSString*)jid;

/**
 Joins the group if it is not joined yet
 */
-(void)join;

/**
 leaves the group if it is joined.
 */
-(void)leave;


@end

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface DCXMPPGroupUser : NSObject

/**
 This is the user in the group.
 */
@property(nonatomic,strong)DCXMPPUser *user;

/**
 This is the role the user has in the group.
 */
@property(nonatomic)DCGroupRole role;

/**
 Returns if the user is the owner of the group
 */
-(BOOL)isOwner;

/**
 Factory method that initalizes and returns a new DCXMPPGroupUser.
 @param user is the DCXMPPUser that is in the group.
 @param is the user's role in the group.
 @return is a new DCXMPPGroupUser.
 */
+(DCXMPPGroupUser*)groupUser:(DCXMPPUser*)user role:(DCGroupRole)role;



@end
