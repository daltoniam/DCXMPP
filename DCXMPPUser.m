////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DCXMPPUser.m
//
//  Created by Dalton Cherry on 11/1/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import "DCXMPPUser.h"
#import "DCXMPP.h"
#import <CommonCrypto/CommonDigest.h>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation DCXMPPUser

////////////////////////////////////////////////////////////////////////////////////////////////////
-(instancetype)initWithJID:(NSString*)jid
{
    if(self = [super init])
    {
        self.presence = DCUserPresenceUnAvailable;
        self.jid = [DCXMPPJID jidWithString:jid];
    }
    return self;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(instancetype)userWithJID:(NSString*)jid
{
    return [[DCXMPPUser alloc] initWithJID:jid];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)name
{
    if(!_name && self.jid)
        return self.jid.name;
    return _name;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(BOOL)isCurrentUser
{
    if([[DCXMPP manager].currentUser.jid.bareJID isEqualToString:self.jid.bareJID])
        return YES;
    return NO;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)sendMessage:(NSString*)text
{
    DCXMPP *stream = [DCXMPP manager];
    NSString *uuid = [DCXMPPUser createUUID:stream.currentUser.jid.bareJID user:self.jid.bareJID];
    NSDictionary* attrs = @{@"to": [self sendJid], @"from": stream.currentUser.jid.fullJID,
                            @"type": [[self class] chatType], @"id": uuid};
    XMLElement* element = [XMLElement elementWithName:@"message" attributes:attrs];
    XMLElement* body = [XMLElement elementWithName:@"body" attributes:nil];
    XMLElement* active = [XMLElement elementWithName:@"active" attributes:@{@"xmlns": XMLNS_CHAT_STATE}];
    body.text = [text xmlSafe];
    [element.childern addObject:body];
    [element.childern addObject:active];
    [stream sendStanza:element];
    return uuid;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)sendTypingState:(DCTypingState)state
{
    NSDictionary* attrs = @{@"to": [self sendJid],
                            @"type": [[self class] chatType]};
    XMLElement* element = [XMLElement elementWithName:@"message" attributes:attrs];
    NSString* name = @"active";
    if(state == DCTypingComposing)
        name = @"composing";
    else if(state == DCTypingInActive)
        name = @"inactive";
    else if(state == DCTypingPaused)
        name = @"paused";

    XMLElement* stateElement = [XMLElement elementWithName:name attributes:@{@"xmlns": XMLNS_CHAT_STATE}];
    [element.childern addObject:stateElement];
    [[DCXMPP manager] sendStanza:element];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)sendJid
{
    NSString *sendJid = self.jid.fullJID;
    if([sendJid rangeOfString:@"/"].location == NSNotFound && self.lastResource && self.lastResource.length > 0)
        sendJid = [sendJid stringByAppendingFormat:@"/%@",self.lastResource];
    return sendJid;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)getVCard
{
    DCXMPP *stream = [DCXMPP manager];
    NSMutableDictionary* attrs = [NSMutableDictionary dictionaryWithCapacity:4];
    [attrs setObject:stream.currentUser.jid.fullJID forKey:@"from"];
    [attrs setObject:[NSString stringWithFormat:@"vcard_get_%@",self.jid.name] forKey:@"id"];
    [attrs setObject:@"get" forKey:@"type"];
    if(![self.jid.bareJID isEqualToString:stream.currentUser.jid.bareJID])
        [attrs setObject:self.jid.fullJID forKey:@"to"];
    XMLElement* element = [XMLElement elementWithName:@"iq" attributes:attrs];
    XMLElement* vcard = [XMLElement elementWithName:@"vCard" attributes:@{@"xmlns": XMLNS_VCARD}];
    [element.childern addObject:vcard];
    [stream sendStanza:element];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)getPresence
{
     XMLElement* element = [XMLElement elementWithName:@"presence" attributes:@{@"to": self.jid.bareJID, @"type": @"probe"}];
    [[DCXMPP manager] sendStanza:element];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)acceptBuddyRequest
{
    XMLElement* element = [XMLElement elementWithName:@"presence" attributes:@{@"to": self.jid.bareJID, @"type": @"subscribe"}];
    [[DCXMPP manager] sendStanza:element];
    [self getVCard];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)declineBuddyRequest
{
    XMLElement* element = [XMLElement elementWithName:@"presence" attributes:@{@"to": self.jid.bareJID, @"type": @"unsubscribe"}];
    [[DCXMPP manager] sendStanza:element];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(NSString*)chatType
{
    return @"chat";
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(NSString*)createUUID:(NSString*)currentJID user:(NSString*)userJID
{
    return [DCXMPPUser sha1HexDigest:[NSString stringWithFormat:@"%@-%@-%f",currentJID,userJID,CFAbsoluteTimeGetCurrent()]];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+ (NSString*)sha1HexDigest:(NSString*)input //md5HexDigest
{
    const char* str = [input UTF8String];
    unsigned char result[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(str, strlen(str), result);
    
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH*2];
    for(int i = 0; i<CC_SHA1_DIGEST_LENGTH; i++)
        [ret appendFormat:@"%02x",result[i]];
    return ret;
}
////////////////////////////////////////////////////////////////////////////////////////////////////

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface DCXMPPGroup ()

@property(nonatomic,strong)NSMutableDictionary *userDict;

@end
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation DCXMPPGroup

////////////////////////////////////////////////////////////////////////////////////////////////////
+(NSString*)chatType
{
    return @"groupchat";
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(DCXMPPGroup*)groupWithJID:(NSString*)jid
{
    DCXMPPGroup *group = [[DCXMPPGroup alloc] initWithJID:jid];
    return group;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)addUser:(DCXMPPUser*)user role:(DCGroupRole)role
{
    if(!self.userDict)
        self.userDict = [NSMutableDictionary new];
    self.userDict[user.jid.bareJID] = [DCXMPPGroupUser groupUser:user role:role];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)removeUser:(DCXMPPUser*)user
{
    [self.userDict removeObjectForKey:user.jid.bareJID];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(DCXMPPGroupUser*)findUser:(DCXMPPUser*)user
{
    return self.userDict[user.jid.bareJID];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)join
{
    if(!self.isJoined)
    {
        DCXMPP *stream = [DCXMPP manager];
        NSDictionary* attrs = @{@"to": [NSString stringWithFormat:@"%@/%@",self.jid.bareJID,stream.currentUser.jid.name]};
        XMLElement* element = [XMLElement elementWithName:@"presence" attributes:attrs];
        
        XMLElement* xElement = [XMLElement elementWithName:@"x" attributes:@{@"xmlns": XMLNS_MUC}];
        [element.childern addObject:xElement];
        
        XMLElement* history = [XMLElement elementWithName:@"history" attributes:@{@"maxchars": @"0"}];
        [xElement.childern addObject:history];
        [stream sendStanza:element];
        _isJoined = YES;
        //NSLog(@"Joined xmpp group: %@ name: %@",self,self.name);
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)leave
{
    XMLElement* element = [XMLElement elementWithName:@"presence" attributes:@{@"type": @"unavailable",
                                                                               @"to": self.jid.fullJID}];
    [[DCXMPP manager] sendStanza:element];
    _isJoined = NO;
    //NSLog(@"left xmpp group: %@ name: %@",self,self.name);
    [self.userDict removeAllObjects];
}
////////////////////////////////////////////////////////////////////////////////////////////////////


@end

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation DCXMPPJID

////////////////////////////////////////////////////////////////////////////////////////////////////
-(instancetype)initWithJID:(NSString*)jid
{
    if(self = [super init])
    {
        self.fullJID = jid;
    }
    return self;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)bareJID
{
    NSString* jid = self.fullJID;
    NSRange range = [jid rangeOfString:@"/"];
    if(range.location != NSNotFound)
        jid = [jid substringToIndex:range.location];
    return jid;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)resource
{
    NSRange range = [self.fullJID rangeOfString:@"/"];
    if(range.location != NSNotFound)
        return [self.fullJID substringFromIndex:range.location+1];
    return nil;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)host
{
    NSRange range = [self.fullJID rangeOfString:@"@"];
    if(range.location != NSNotFound)
    {
        NSString* host = [self.fullJID substringFromIndex:range.location+1];
        range = [host rangeOfString:@"/"];
        if(range.location != NSNotFound)
            return [host substringToIndex:range.location];
        return host;
    }
    return nil;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)name
{
    NSRange range = [self.fullJID rangeOfString:@"@"];
    if(range.location != NSNotFound)
        return [self.fullJID substringToIndex:range.location];
    return nil;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(DCXMPPJID*)jidWithString:(NSString*)jid
{
    return [[DCXMPPJID alloc] initWithJID:jid];
}
////////////////////////////////////////////////////////////////////////////////////////////////////

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation DCXMPPGroupUser

////////////////////////////////////////////////////////////////////////////////////////////////////
+(DCXMPPGroupUser*)groupUser:(DCXMPPUser*)user role:(DCGroupRole)role
{
    DCXMPPGroupUser *groupUser = [DCXMPPGroupUser new];
    groupUser.user = user;
    groupUser.role = role;
    return groupUser;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(BOOL)isOwner
{
    if(self.role == DCGroupRoleOwner)
        return YES;
    return NO;
}
////////////////////////////////////////////////////////////////////////////////////////////////////

@end
