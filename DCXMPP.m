////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DCXMPP.m
//
//  Created by Dalton Cherry on 10/31/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import "DCXMPP.h"
#import "BoshRequest.h"
#import "NSData+base64.h"

@interface DCXMPP ()

//set if we are using a custom connection method
@property(nonatomic,assign)BOOL isCustomConnect;

//this handles queuing of the data you want to send to the server
@property(nonatomic,strong)NSMutableArray* contentQueue;

//the current running operations.
@property(nonatomic,assign)int optCount;

//lock for all the multi threading.
@property(nonatomic,strong)NSLock *optLock;

//lock for all the delegate multi threading.
@property(nonatomic,strong)NSLock *delegateLock;

//the max amount of operations that can be run at a time.
@property(nonatomic,assign)int maxCount;

//this is the bosh rid
@property(nonatomic,assign)long long boshRID;

//this is the bosh sid
@property(nonatomic,copy)NSString *boshSID;

//the host we are connected to
@property(nonatomic,copy)NSString *host;

//the boshURL we are connected to
@property(nonatomic,copy)NSString *boshURL;

//the timeout of how long a connection can stay open.
@property(nonatomic,assign)int timeout;

//the username of the person logging in
@property(nonatomic,copy)NSString *userName;

//the password of the person logging in
@property(nonatomic,copy)NSString *password;

//we are trying to authenicate
@property(nonatomic,assign)BOOL isAuthing;

//All the users from groups or the roster
@property(nonatomic,strong)NSMutableDictionary *users;

//The users in the current user's roster
@property(nonatomic,strong)NSMutableDictionary *rosterUsers;

//The users in the current user's groups
@property(nonatomic,strong)NSMutableDictionary *groups;

@end

@implementation DCXMPP

////////////////////////////////////////////////////////////////////////////////////////////////////
+(instancetype)manager
{
    static DCXMPP *xmpp = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        xmpp = [[[self class] alloc] init];
    });
    return xmpp;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)connect:(NSString*)userName password:(NSString*)password host:(NSString*)host boshURL:(NSString*)boshURL
{
    self.isCustomConnect = NO;
    if(!self.isConnected)
    {
        if(!self.delegateLock)
            self.delegateLock = [NSLock new];
        self.password = password;
        self.userName = userName;
        self.maxCount = 2;
        self.host = host;
        self.boshURL = boshURL;
        self.timeout = 5;
        self.boshRID = [self generateRid];
        NSDictionary *attributes = @{@"content": @"text/xml; charset=utf-8",
                                     @"hold": @"3",
                                     @"rid": [NSString stringWithFormat:@"%lld",self.boshRID],
                                     @"from": [NSString stringWithFormat:@"%@@%@",userName,host],
                                     @"to": host,
                                     @"window": @"5",
                                     @"wait": @"5",
                                     @"xmlns": XMLNS_BOSH,
                                     @"xmpp:version": @"1.0",
                                     @"xmlns:xmpp": @"urn:xmpp:xbosh"};
        XMLElement *content = [XMLElement elementWithName:@"body" attributes:attributes];
        [self addContent:content];
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)connect:(NSString*)jid rid:(long long)rid sid:(NSString*)sid host:(NSString*)host boshURL:(NSString*)boshURL
{
    self.isCustomConnect = YES;
    [self.contentQueue removeAllObjects];
    if(!jid || !sid || rid <= 0 || !host || !boshURL)
    {
        self.boshSID = nil;
        if([self.delegate respondsToSelector:@selector(didFailXMPPLogin)])
            [self.delegate didFailXMPPLogin];
        return;
    }
    if(!self.delegateLock)
        self.delegateLock = [NSLock new];
    self.boshSID = sid;
    self.maxCount = 2;
    self.host = host;
    self.timeout = 5;
    self.boshURL = boshURL;
    self.boshRID = rid;
    _currentUser = [DCXMPPUser userWithJID:jid];
    _currentUser.presence = DCUserPresenceAvailable;
    _isConnected = YES;
    [self setPresence:DCUserPresenceAvailable status:nil];
    [self getRoster];
    //[self getBookmarks];
    [self.currentUser getVCard];
    if([self.delegate respondsToSelector:@selector(didXMPPConnect)])
        [self.delegate didXMPPConnect];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(DCXMPPUser*)userForJid:(NSString*)jid
{
    return self.users[jid];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(DCXMPPGroup*)groupForJid:(NSString*)jid
{
    return self.groups[jid];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)addGroup:(DCXMPPGroup*)group
{
    if(!self.groups)
        self.groups = [[NSMutableDictionary alloc] init];
    if(!self.groups[group.jid.bareJID])
        [self.groups setObject:group forKey:group.jid.bareJID];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
//roster processing
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)getRoster
{
    XMLElement* element = [XMLElement elementWithName:@"iq" attributes:@{@"type": @"get",
                                                                         @"from": self.currentUser.jid.fullJID,
                                                                         @"id": @"roster_1"}];
    XMLElement* query = [XMLElement elementWithName:@"query" attributes:@{@"xmlns": @"jabber:iq:roster"}];
    [element.childern addObject:query];
    [self addContent:element];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)handleRosterResponse:(NSArray*)elements
{
    if(!self.roster)
        _roster = [[NSMutableArray alloc] initWithCapacity:elements.count];
    
    if(!self.rosterUsers)
        self.rosterUsers = [[NSMutableDictionary alloc] initWithCapacity:elements.count];
    
    if(!self.users)
        self.users = [[NSMutableDictionary alloc] initWithCapacity:elements.count];
    
    [self.users removeObjectsForKeys:[self.rosterUsers allKeys]];
    [self.rosterUsers removeAllObjects];
    [(NSMutableArray*)_roster removeAllObjects];
    for(XMLElement *element in elements)
    {
        DCXMPPUser *user = [DCXMPPUser userWithJID:element.attributes[@"jid"]];
        user.name = element.attributes[@"name"];
        [self.users setObject:user forKey:user.jid.bareJID];
        [self.rosterUsers setObject:user forKey:user.jid.bareJID];
        [(NSMutableArray*)_roster addObject:user];
    }
    if([self.delegate respondsToSelector:@selector(didRecieveRoster:)])
        [self.delegate didRecieveRoster:self.roster];
    [self setPresence:DCUserPresenceAvailable status:nil];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
//bookmark processing
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)getBookmarks
{
    XMLElement* element = [XMLElement elementWithName:@"iq" attributes:@{@"type": @"get",
                                                                         @"from": self.currentUser.jid.fullJID,
                                                                         @"id": @"bookmark_1"}];
    XMLElement* query = [XMLElement elementWithName:@"query" attributes:@{@"xmlns": @"jabber:iq:private"}];
    [element.childern addObject:query];
    XMLElement* storage = [XMLElement elementWithName:@"storage" attributes:@{@"xmlns": @"storage:bookmarks"}];
    [query.childern addObject:storage];
    [self addContent:element];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)handleBookmarksResponse:(XMLElement*)element
{
    NSArray* confs = [element findElements:@"conference"];
    if(confs.count > 0)
    {
        if(!self.groups)
            self.groups = [[NSMutableDictionary alloc] initWithCapacity:confs.count];
        [self.groups removeAllObjects];
        for(XMLElement* child in confs)
        {
            DCXMPPGroup *group = [DCXMPPGroup groupWithJID:child.attributes[@"jid"]];
            group.name = child.attributes[@"name"];
            [self.groups setObject:group forKey:group.jid.bareJID];
            if([child.attributes[@"autojoin"] boolValue])
                [group join];
        }
    }
    if([self.delegate respondsToSelector:@selector(didRecieveBookmarks)])
        [self.delegate didRecieveBookmarks];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
//content queueing
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)sendStanza:(XMLElement*)element
{
    if(self.isConnected)
        [self addContent:element];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)sendMessage:(NSString *)text jid:(NSString*)jid
{
    if(self.isConnected)
    {
        DCXMPPUser *user = self.users[jid];
        if(!user)
            user = self.groups[jid];
        if(user)
            [user sendMessage:text];
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)sendTypingState:(DCTypingState)state jid:(NSString*)jid
{
    if(self.isConnected)
    {
        DCXMPPUser *user = self.users[jid];
        if(!user)
            user = self.groups[jid];
        if(user)
            [user sendTypingState:state];
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)addContent:(XMLElement*)element
{
    if(!self.contentQueue)
        self.contentQueue = [NSMutableArray new];
    if(![element.name isEqualToString:@"body"])
    {
        if(!self.boshSID)
            NSLog(@"Error: boshSID: %@",[element convertToString]);
        XMLElement *body = [XMLElement elementWithName:@"body"
                                            attributes:@{@"rid": [NSString stringWithFormat:@"%lld",self.boshRID],
                                                         @"sid": self.boshSID,@"xmlns": XMLNS_BOSH}];
        [body.childern addObject:element];
        [self.contentQueue addObject:body];
        //NSLog(@"Sending: %@",[body convertToString]);
    }
    else
    {
        [self.contentQueue addObject:element];
        //NSLog(@"Sending: %@",[element convertToString]);
    }
    [self dequeue];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)dequeue
{
    [self dequeue:self.timeout];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)dequeue:(int)timeout
{
    if(self.optCount < self.maxCount)
    {
        NSString *postText = nil;
        if(self.contentQueue.count > 0)
        {
            postText = [self.contentQueue[0] convertToString];
            [self.contentQueue removeObjectAtIndex:0];
        }
        else
        {
            postText = [NSString stringWithFormat:@"<body rid='%lld' sid='%@' xmlns='%@'></body>",self.boshRID,self.boshSID,XMLNS_BOSH];
        }
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.boshURL]];
        [request setTimeoutInterval:self.timeout];
        NSData *postBody = [postText dataUsingEncoding:NSUTF8StringEncoding];
        unsigned long long postLength = postBody.length;
        NSString *contentLength = [NSString stringWithFormat:@"%llu", postLength];
        [request addValue:contentLength forHTTPHeaderField:@"Content-Length"];
        [request addValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [request addValue:@"text/xml" forHTTPHeaderField:@"Accept"];
        [request addValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:postBody];
        [self sendRequest:request];
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)sendRequest:(NSURLRequest*)request
{
    if(!self.optLock)
        self.optLock = [[NSLock alloc] init];
    [self.optLock lock];
    self.optCount++;
    [self.optLock unlock];
    BoshRequest* opt = [[BoshRequest alloc] initWithRequest:request];
    opt.delegate = (id<BoshRequestDelegate>)self;
    [opt start];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)requestFinished:(BoshRequest*)request
{
    [self.optLock lock];
    self.optCount--;
    [self.optLock unlock];
    XMLElement* element = [request responseElement];
    //NSLog(@"Recieving: %@\n\n",[element convertToString]);
    if([self processResponse:element])
        [self dequeue];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)requestFailed:(BoshRequest*)request
{
    [self.optLock lock];
    self.optCount--;
    [self.optLock unlock];
    [self dequeue];
    //NSLog(@"request time out");
}
////////////////////////////////////////////////////////////////////////////////////////////////////
//process responses
////////////////////////////////////////////////////////////////////////////////////////////////////
-(BOOL)processResponse:(XMLElement*)element
{
    if(!self.isConnected)
    {
        if(self.isCustomConnect)
            return NO;
        if(self.isAuthing)
        {
            XMLElement* success = [element findElement:@"success"];
            if(success)
            {
                XMLElement* element = [XMLElement elementWithName:@"body"
                                                       attributes:@{@"sid": self.boshSID,
                                                                    @"xmpp:restart": @"true",
                                                                    @"rid": [NSString stringWithFormat:@"%lld",self.boshRID],
                                                                    @"xmlns": XMLNS_BOSH,
                                                                    @"xmpp:version": @"1.0",
                                                                    @"xmlns:xmpp": @"urn:xmpp:xbosh"}];
                [self addContent:element];
                
                self.isAuthing = NO;
            }
            else
            {
                self.boshSID = nil;
                [self.delegateLock lock];
                if([self.delegate respondsToSelector:@selector(didFailXMPPLogin)])
                    [self.delegate didFailXMPPLogin];
                [self.delegateLock unlock];
                return NO;
            }
            
        }
        XMLElement* bind = [element findElement:@"bind"];
        if(bind)
        {
            XMLElement* jidElement = [element findElement:@"jid"];
            if(jidElement)
            {
                XMLElement* element = [XMLElement elementWithName:@"iq" attributes:@{@"type": @"set",
                                                                                     @"id": @"sess_1",
                                                                                     @"xmlns": XMLNS_CLIENT}];
                XMLElement* sesson = [XMLElement elementWithName:@"session" attributes:@{@"xmlns": XMLNS_SESSION}];
                [element.childern addObject:sesson];
                [self addContent:element];
                NSString* jid = jidElement.text;
                _currentUser = [DCXMPPUser userWithJID:jid];
                _currentUser.presence = DCUserPresenceAvailable;
                _isConnected = YES;
                //[self addContent:[XMLElement elementWithName:@"presence" attributes:nil]];
                [self getRoster];
                [self getBookmarks];
                [self.currentUser getVCard];
                if([self.delegate respondsToSelector:@selector(didXMPPConnect)])
                    [self.delegate didXMPPConnect];
            }
            else
            {
                XMLElement* element = [XMLElement elementWithName:@"iq" attributes:@{@"type": @"set",
                                                                                     @"id": @"bind_1",
                                                                                     @"xmlns": XMLNS_CLIENT}];
                XMLElement* bind = [XMLElement elementWithName:@"bind" attributes:@{@"xmlns": XMLNS_BIND}];
                [element.childern addObject:bind];
                [self addContent:element];
            }
        }
        else
        {
            NSString *sid = element.attributes[@"sid"];
            if(sid)
                self.boshSID = sid;
            
            NSString *optCount = element.attributes[@"requests"];
            if(optCount)
                self.maxCount = [optCount intValue];
            
            NSString *polling = element.attributes[@"polling"];
            if(polling)
                self.timeout = [polling intValue];

            XMLElement* features = [element findElement:@"stream:features"];
            if(features)
                [self handleAuthenication:features];
        }
    }
    else
    {
        if([element.name isEqualToString:@"body"] && [element.attributes[@"type"] isEqualToString:@"terminate"])
        {
            if(self.isConnected)
            {
                _isConnected = NO;
                for(id key in self.groups)
                {
                    DCXMPPGroup *group = self.groups[key];
                    [group leave];
                }
                [self.contentQueue removeAllObjects];
                self.boshSID = nil;
                NSLog(@"bosh connection terminated: %@",[element convertToString]);
                if([self.delegate respondsToSelector:@selector(didFailXMPPLogin)])
                    [self.delegate didFailXMPPLogin];
            }
            return YES;
        }
        else if(element.childern.count > 0 && [element.name isEqualToString:@"body"])
        {
            for(XMLElement* response in element.childern)
            {
                //NSLog(@"response: %@",[response convertToString]);
                if([response.attributes[@"id"] isEqualToString:@"roster_1"])
                    [self handleRosterResponse:[response findElements:@"item"]];
                else if([response.attributes[@"id"] isEqualToString:@"bookmark_1"])
                    [self handleBookmarksResponse:response];
                else if([response.name isEqualToString:@"message"] && [response.attributes[@"type"] rangeOfString:@"chat"].location != NSNotFound)
                    [self handleMessageResponse:response];
                if([response.attributes[@"id"] hasPrefix:@"vcard_get"])
                    [self handleVCardResponse:response];
                if([response.name isEqualToString:@"presence"])
                    [self handlePresenceResponse:response];
            }
        }
    }
    return YES;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)handleMessageResponse:(XMLElement*)element
{
    NSString *jidString = element.attributes[@"from"];
    DCXMPPJID *jid = [DCXMPPJID jidWithString:jidString];
    
    XMLElement* xElement = [element findElement:@"x"];
    if(xElement)
    {
        if([xElement.attributes[@"xmlns"] isEqualToString:@"jabber:x:conference"])
        {
            //[self fetchDiscoInfo:[xElement.attributes objectForKey:@"jid"]];
            return;
        }
    }
    
    DCXMPPGroup *group = self.groups[jid.bareJID];
    DCXMPPUser *user = nil;
    if(group)
    {
        if(jid.resource)
        {
            NSString *groupUserJid = [NSString stringWithFormat:@"%@@%@",jid.resource,self.host];
            user = self.users[groupUserJid];
        }
    }
    else
        user = self.users[jid.bareJID];
    
    if(user)
    {
        XMLElement *body = [element findElement:@"body"];
        if(body && body.text)
        {
            if(group)
            {
                if(self.currentUser.jid.bareJID == user.jid.bareJID)
                {
                    if([self.delegate respondsToSelector:@selector(didRecieveGroupCarbon:group:from:)])
                        [self.delegate didRecieveGroupCarbon:body.text group:group from:user];
                }
                else if([self.delegate respondsToSelector:@selector(didRecieveGroupMessage:group:from:)])
                    [self.delegate didRecieveGroupMessage:body.text group:group from:user];
            }
            else if([self.delegate respondsToSelector:@selector(didRecieveMessage:from:)] && self.currentUser.jid.bareJID != jid.bareJID)
                [self.delegate didRecieveMessage:body.text from:user];
        }
        else
        {
            if(self.currentUser.jid.bareJID == jid.bareJID)
                   return;
            DCTypingState state = DCTypingActive;
            if([element findElement:@"composing"])
                state = DCTypingComposing;
            else if([element findElement:@"inactive"])
                state = DCTypingInActive;
            else if([element findElement:@"paused"])
                state = DCTypingPaused;
            else if([element findElement:@"gone"])
                state = DCTypingGone;
            
            if(group)
            {
                if([self.delegate respondsToSelector:@selector(didRecieveGroupTypingState:group:from:)])
                    [self.delegate didRecieveGroupTypingState:state group:group from:user];
            }
            else if([self.delegate respondsToSelector:@selector(didRecieveTypingState:from:)])
                [self.delegate didRecieveTypingState:state from:user];
        }
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)handleVCardResponse:(XMLElement*)element
{
    NSString *jidString = element.attributes[@"from"];
    DCXMPPUser *user = nil;
    if(!jidString || [self.currentUser.jid.bareJID isEqualToString:jidString])
        user = self.currentUser;
    else
    {
        DCXMPPJID *jid = [DCXMPPJID jidWithString:jidString];
        user = self.users[jid.bareJID];
    }
    if(user)
    {
        [self.delegateLock lock];
        XMLElement *nameElement = [element findElement:@"fn"];
        if(nameElement && nameElement.text.length > 0)
            user.name = [nameElement.text xmlUnSafe];
        NSString* string = [element findElement:@"binval"].text;
        if(string)
        {
            user.avatarData = [string dataUsingEncoding:NSASCIIStringEncoding];
            user.avatarData = [user.avatarData base64Decoded];
        }
        if([self.delegate respondsToSelector:@selector(didUpdateVCard:)])
            [self.delegate didUpdateVCard:user];
        [self.delegateLock unlock];
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)handlePresenceResponse:(XMLElement*)element
{
    NSString *type = element.attributes[@"type"];
    NSString *jidString = element.attributes[@"from"];
    DCXMPPJID *jid = [DCXMPPJID jidWithString:jidString];
    DCXMPPUser *user = self.users[jid.bareJID];
    if(user)
    {
        [self.delegateLock lock];
        XMLElement* statusElement = [element findElement:@"status"];
        if(statusElement && !type)
            type = [statusElement.text lowercaseString];
        if(!type)
            user.presence = DCUserPresenceAvailable;
        else if([type isEqualToString:@"unavailable"])
            user.presence = DCUserPresenceUnAvailable;
        else if([type isEqualToString:@"available"])
            user.presence = DCUserPresenceAvailable;
        else if([type isEqualToString:@"busy"])
            user.presence = DCUserPresenceBusy;
        
        XMLElement* showElement = [element findElement:@"show"];
        if(showElement)
        {
            if([showElement.text isEqualToString:@"chat"])
                user.presence = DCUserPresenceAvailable;
            else if([showElement.text isEqualToString:@"away"])
                user.presence = DCUserPresenceAway;
            else if([showElement.text isEqualToString:@"xa"])
                user.presence = DCUserPresenceAway;
            else if([showElement.text isEqualToString:@"dnd"])
                user.presence = DCUserPresenceBusy;
        }
        if(statusElement)
            user.status = [statusElement.text xmlUnSafe];
        else
            user.status = nil;
        
        XMLElement* photoElement = [element findElement:@"photo"];
        if(photoElement)
            user.imageHash = photoElement.text;
        
        if([self.delegate respondsToSelector:@selector(didUpdatePresence:)])
            [self.delegate didUpdatePresence:user];
        [self.delegateLock unlock];
    }
    
    DCXMPPGroup *group = self.groups[jid.bareJID];
    if(group)
    {
        NSArray *items = [element findElements:@"item"];
        for(XMLElement *itemElement in items)
        {
            NSString *itemJidString = itemElement.attributes[@"jid"];
            if(itemJidString)
            {
                DCXMPPJID *itemJid = [DCXMPPJID jidWithString:itemJidString];
                NSString *roleType = itemElement.attributes[@"affiliation"];
                DCGroupRole role = DCGroupRoleMember;
                if([roleType isEqualToString:@"owner"])
                    role = DCGroupRoleOwner;
                DCXMPPUser *user = self.users[itemJid.bareJID];
                if([itemJid.bareJID isEqualToString:self.currentUser.jid.bareJID])
                    user = self.currentUser;
                BOOL isLeaving = NO;
                if([type isEqualToString:@"unavailable"])
                    isLeaving = YES;
                if(isLeaving)
                {
                    if(!user)
                        return;
                    if([self.delegate respondsToSelector:@selector(userDidLeaveGroup:user:)])
                        [self.delegate userDidLeaveGroup:group user:user];
                    [group removeUser:user];
                    return;
                }
                
                //user is already in the group
                if([group findUser:user])
                    return;
                
                if(!user)
                {
                    DCXMPPUser *user = [DCXMPPUser userWithJID:itemJidString];
                    user.presence = DCUserPresenceAvailable; //if they are in the group, then the are probably avaliable, just saying
                    [self.users setObject:user forKey:user.jid.bareJID];
                    [user getVCard];
                    [user getPresence];
                    //NSLog(@"user: %@ is not in our roster....",itemJid.bareJID);
                    [group addUser:user role:role];
                }
                else
                    [group addUser:user role:role];
                [self.delegateLock lock];
                if([self.delegate respondsToSelector:@selector(userDidJoinGroup:user:)])
                    [self.delegate userDidJoinGroup:group user:user];
                [self.delegateLock unlock];
            }
        }
        //NSLog(@"need to finish group element: %@",[element convertToString]);
    }
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)setPresence:(DCUserPresence)presence status:(NSString*)status
{
    [self setPresence:presence status:status to:nil];
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)setPresence:(DCUserPresence)presence status:(NSString*)status to:(NSString*)jid //priority:(int)priority
{
    if(self.isConnected)
    {
        XMLElement* element = [self buildPresence:presence status:status to:jid];
        if(!jid)
        {
            for(id key in self.groups)
            {
                DCXMPPGroup *group = self.groups[key];
                if(group.isJoined)
                {
                    [element.childern addObject:[self buildPresence:presence status:status to:group.jid.bareJID]];
                    //content = [content stringByAppendingString:[self buildPresence:presence status:status to:group.jid.bareJID]];
                }
            }
        }
        self.currentUser.status = status;
        self.currentUser.presence = presence;
        [self addContent:element];
    }
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-(XMLElement*)buildPresence:(DCUserPresence)presence status:(NSString*)status to:(NSString*)jid
{
    NSDictionary* attrs = nil;
    if(jid)
        attrs = @{@"xmlns": @"jabber:client", @"to": jid};
    else
        attrs = @{@"xmlns": @"jabber:client"};
    XMLElement* element = [XMLElement elementWithName:@"presence" attributes:attrs];
    
    XMLElement* proElement = [XMLElement elementWithName:@"priority" attributes:nil];
    proElement.text = [NSString stringWithFormat:@"%d",0];
    [element.childern addObject:proElement];
    
    if(presence != DCUserPresenceAvailable)
    {
        XMLElement* show = [XMLElement elementWithName:@"show" attributes:nil];
        if(presence == DCUserPresenceAway)
            show.text = @"away";
        else if(presence == DCUserPresenceBusy)
            show.text = @"dnd";
        //else
        //    show.text = @"chat";
        [element.childern addObject:show];
    }
    
    if(status)
    {
        if( (presence == DCUserPresenceAway && [[status lowercaseString] isEqualToString:@"away"]) ||
           (presence == DCUserPresenceBusy && [[status lowercaseString] isEqualToString:@"busy"]) ){}
        else
        {
            XMLElement* statusElement = [XMLElement elementWithName:@"status" attributes:nil];
            statusElement.text = status;
            [element.childern addObject:statusElement];
        }
    }
    if(self.currentUser.avatarData)
    {
        XMLElement* xElement = [XMLElement elementWithName:@"x" attributes:@{@"xmlns": @"vcard-temp:x:update"}];
        XMLElement* photoElement = [XMLElement elementWithName:@"photo" attributes:nil];
        photoElement.text = self.currentUser.imageHash;
        [xElement.childern addObject:photoElement];
        [element.childern addObject:xElement];
    }
    return element;//[element convertToString];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
//Authenication stuff
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)handleAuthenication:(XMLElement*)element
{
    self.isAuthing = YES;
    NSArray* mechs = [element findElements:@"mechanism"];
    NSMutableArray* collect = [NSMutableArray arrayWithCapacity:mechs.count];
    for(XMLElement* mech in mechs)
        [collect addObject:mech.text];
    //if([collect containsObject:@"DIGEST-MD5"]) could/should add a lot more authenication routines.
    //    [self md5Authenication];
    if([collect containsObject:@"PLAIN"])
        [self saslAuthenication];
    
}
//////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)saslAuthenication
{
    NSString *payload = [NSString stringWithFormat:@"%C%@%C%@", (short)0, self.userName, (short)0, self.password];
    XMLElement* element = [XMLElement elementWithName:@"auth" attributes:@{@"mechanism": @"PLAIN", @"xmlns": @"urn:ietf:params:xml:ns:xmpp-sasl"}];
    element.text = [[payload dataUsingEncoding:NSUTF8StringEncoding] base64String];
    [self addContent:element];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(long long)boshRID
{
    long long val = _boshRID;
    _boshRID++;
    return val;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)md5Authenication
{
    // Implement me!!!
}
////////////////////////////////////////////////////////////////////////////////////////////////////
- (long long)generateRid
{
    return (arc4random() % 1000000000LL + 1000000001LL);
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(long long)currentBoshRID
{
    return _boshRID;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)currentBoshSID
{
    return self.boshSID;
}
////////////////////////////////////////////////////////////////////////////////////////////////////

@end
