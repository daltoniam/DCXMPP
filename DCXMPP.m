////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DCXMPP.m
//
//  Created by Dalton Cherry on 10/31/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import "DCXMPP.h"
#import "XMLKit.h"
#import "BoshRequest.h"
#import "NSData+base64.h"

@interface DCXMPP ()

//this handles queuing of the data you want to send to the server
@property(nonatomic,strong)NSMutableArray* contentQueue;

//the current running operations.
@property(nonatomic,assign)int optCount;

//lock for all the multi threading.
@property(nonatomic,strong)NSLock *optLock;

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

@end

@implementation DCXMPP

static NSString *XMLNS_BOSH = @"http://jabber.org/protocol/httpbind";
static NSString *XMLNS_CHAT_STATE = @"http://jabber.org/protocol/chatstates";
static NSString *BIND_XMLNS = @"urn:ietf:params:xml:ns:xmpp-bind";
static NSString *CLIENT_XMLNS  = @"jabber:client";
static NSString *SESSION_XMLNS = @"urn:ietf:params:xml:ns:xmpp-session";
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
    if(!self.isConnected)
    {
        self.password = password;
        self.userName = userName;
        self.maxCount = 2;
        self.host = host;
        self.boshURL = boshURL;
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
-(void)addContent:(XMLElement*)element
{
    if(!self.contentQueue)
        self.contentQueue = [NSMutableArray new];
    if(![element.name isEqualToString:@"body"])
    {
        XMLElement *body = [XMLElement elementWithName:@"body"
                                            attributes:@{@"rid": [NSString stringWithFormat:@"%lld",self.boshRID],
                                                         @"sid": self.boshSID,@"xmlns": XMLNS_BOSH}];
        [body.childern addObject:element];
        [self.contentQueue addObject:body];
    }
    else
        [self.contentQueue addObject:element];
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
        [request setTimeoutInterval:30];
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
    //NSLog(@"opt request: %@\n\n",[element convertToString]);
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
    //NSLog(@"request failed");
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(BOOL)processResponse:(XMLElement*)element
{
    if(!self.isConnected)
    {
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
                //notify delegate that we didn't authenicate
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
                                                                                     @"xmlns": CLIENT_XMLNS}];
                XMLElement* sesson = [XMLElement elementWithName:@"session" attributes:@{@"xmlns": SESSION_XMLNS}];
                [element.childern addObject:sesson];
                [self addContent:element];
                NSString* jid = jidElement.text;
                NSLog(@"we got our jid: %@",jid);
                //got our jid!
                /*userJID = [[rootElement findElement:@"jid"] text];
                self.userItem = [GPXMPPUser userWithName:nil jid:self.userJID];
                self.userItem.presence = GPUserPresenceAvailable;
                [self goOnline];
                [self fetchRoster];
                isConnected = YES;
                [self sendListen];
                if([self.delegate respondsToSelector:@selector(didConnect)])
                    [self.delegate didConnect];*/
            }
            else
            {
                XMLElement* element = [XMLElement elementWithName:@"iq" attributes:@{@"type": @"set",
                                                                                     @"id": @"bind_1",
                                                                                     @"xmlns": CLIENT_XMLNS}];
                XMLElement* bind = [XMLElement elementWithName:@"bind" attributes:@{@"xmlns": BIND_XMLNS}];
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
    return YES;
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
    XMLElement* element = [XMLElement elementWithName:@"auth" attributes:[NSDictionary dictionaryWithObjectsAndKeys:@"PLAIN",@"mechanism",@"urn:ietf:params:xml:ns:xmpp-sasl",@"xmlns", nil]];
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

@end
