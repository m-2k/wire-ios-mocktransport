// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


#import "MockTransportSessionTests.h"

#import "MockPushEvent.h"
@import ZMProtos;

@interface MockTransportSessionConversationsTests : MockTransportSessionTests

@end

@implementation MockTransportSessionConversationsTests


- (void)testThatWeCanRequestMessagesInAConversation
{
    // given
    const NSUInteger numMessages = 300;
    NSUUID *conversationID = [NSUUID createUUID];
    NSMutableArray *expectedPayloads = [NSMutableArray array];
    __block MockUser *selfUser;
    __block MockUser *user1;
    __block MockUser *user2;
    
    __block MockConversation *groupConversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        user1 = [session insertUserWithName:@"Foo"];
        user2 = [session insertUserWithName:@"Bar"];
        
        groupConversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1, user2]];
        groupConversation.creator = user2;
        groupConversation.identifier = conversationID.transportString;
        
        // create messages
        for(NSUInteger i = 0; i < numMessages; ++i) {
            [groupConversation insertTextMessageFromUser:user1 text:@"Fuuuuuu" nonce:[NSUUID createUUID]];
        }
        
        // expected response
        [expectedPayloads addObjectsFromArray:[groupConversation.events.array mapWithBlock:^id(MockEvent *obj) {
            return obj.transportData;
        }]];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    NSString *path = [NSString stringWithFormat:@"/conversations/%@/events", conversationID.transportString];
    ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
    
    // then
    XCTAssertNotNil(response);
    if (!response) {
        return;
    }
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertNil(response.transportSessionError);
    AssertEqualDictionaries((NSDictionary *)response.payload, @{@"events":expectedPayloads});
}


- (void)testThatWeCanRequestMessagesInAConversationWithLimit
{
    // given
    const NSUInteger numMessages = 300;
    const NSUInteger messagesInRequest = 100;
    NSUUID *conversationID = [NSUUID createUUID];
    NSMutableArray *expectedPayloads = [NSMutableArray array];
    __block MockUser *selfUser;
    __block MockUser *user1;
    __block MockUser *user2;
    
    __block MockConversation *groupConversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        user1 = [session insertUserWithName:@"Foo"];
        user2 = [session insertUserWithName:@"Bar"];
        
        groupConversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1, user2]];
        groupConversation.creator = user2;
        groupConversation.identifier = conversationID.transportString;
        
        // create messages
        for(NSUInteger i = 0; i < numMessages; ++i) {
            [groupConversation insertTextMessageFromUser:user1 text:@"Fuuuuuu" nonce:[NSUUID createUUID]];
        }
        
        // expected response
        NSUInteger count = 0;
        for(MockEvent *message in groupConversation.events)
        {
            if(count > messagesInRequest) {
                break;
            }
            [expectedPayloads addObject:message.transportData];
            ++count;
        }
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    NSString *path = [NSString stringWithFormat:@"/conversations/%@/events?limit=%lu", conversationID.transportString, (unsigned long)messagesInRequest];
    ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
    
    // then
    XCTAssertNotNil(response);
    if (!response) {
        return;
    }
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertNil(response.transportSessionError);
    AssertEqualDictionaries((NSDictionary *)response.payload, @{@"events":expectedPayloads});
}

- (void)testThatWeCanRequestMessagesInAConversationWithStartingPointAndEndPoint
{
    // given
    const NSUInteger numMessages = 300;
    const NSUInteger startMessageSequence = 10;
    const NSUInteger endMessageSequence = 34;
    NSUUID *conversationID = [NSUUID createUUID];
    NSMutableArray *expectedPayloads = [NSMutableArray array];
    __block MockUser *selfUser;
    __block MockUser *user1;
    __block MockUser *user2;
    __block MockConversation *groupConversation;
    __block ZMEventID *lastMessageEventID;
    
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        user1 = [session insertUserWithName:@"Foo"];
        user2 = [session insertUserWithName:@"Bar"];
        
        groupConversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1, user2]];
        groupConversation.creator = user2;
        groupConversation.identifier = conversationID.transportString;
        
        // create messages
        for(NSUInteger i = 0; i < numMessages; ++i) {
            [groupConversation insertTextMessageFromUser:user1 text:@"Fuuuuuu" nonce:[NSUUID createUUID]];
        }
        
        // expected response
        for(MockEvent *message in groupConversation.events)
        {
            ZMEventID *eventID = [ZMEventID eventIDWithString:message.identifier];
            if(eventID.major < startMessageSequence || eventID.major > endMessageSequence) {
                continue;
            }
            if(eventID.major == endMessageSequence) {
                lastMessageEventID = eventID;
            }
            [expectedPayloads addObject:message.transportData];
        }
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    NSString *path = [NSString stringWithFormat:@"/conversations/%@/events?start=%lx.0&end=%@", conversationID.transportString, (unsigned long)startMessageSequence, lastMessageEventID.transportString];
    ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
    
    // then
    XCTAssertNotNil(response);
    if (!response) {
        return;
    }
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertNil(response.transportSessionError);
    AssertEqualDictionaries((NSDictionary *)response.payload, @{@"events":expectedPayloads});
}

- (void)testThatWeCanManuallyCreateAndRequestConversations;
{
    // given
    __block MockUser *selfUser;
    __block MockUser *user1;
    __block MockUser *user2;
    
    __block MockConnection *connection1;
    
    __block MockConversation *selfConversation;
    __block MockConversation *oneOnOneConversation;
    __block MockConversation *groupConversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        user1 = [session insertUserWithName:@"Foo"];
        user2 = [session insertUserWithName:@"Bar"];
        
        connection1 = [session insertConnectionWithSelfUser:selfUser toUser:user1];
        connection1.status = @"accepted";
        connection1.lastUpdate = [NSDate dateWithTimeIntervalSince1970:1399920861.091];
        
        selfConversation = [session insertSelfConversationWithSelfUser:selfUser];
        oneOnOneConversation = [session insertOneOnOneConversationWithSelfUser:selfUser otherUser:user1];
        oneOnOneConversation.creator = user1;
        groupConversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1, user2]];
        groupConversation.creator = user2;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // (1)
    {
        // when
        ZMTransportResponse *response = [self responseForPayload:nil path:@"/conversations/" method:ZMMethodGET];
        
        // then
        XCTAssertNotNil(response);
        if (!response) {
            return;
        }
        XCTAssertEqual(response.HTTPStatus, 200);
        XCTAssertNil(response.transportSessionError);
        XCTAssertTrue([response.payload isKindOfClass:[NSDictionary class]]);
        
        NSArray *data = [[response.payload asDictionary] arrayForKey:@"conversations"];
        XCTAssertNotNil(data);
        XCTAssertEqual(data.count, (NSUInteger) 3);
        
        [self checkThatTransportData:data[0] matchesConversation:selfConversation];
        [self checkThatTransportData:data[1] matchesConversation:oneOnOneConversation];
        [self checkThatTransportData:data[2] matchesConversation:groupConversation];
    }
    
    // (2)
    for (MockConversation *conversation in @[selfConversation, oneOnOneConversation, groupConversation]) {
        return; // 1 TODO: Fix threading violation here
        // -com.apple.CoreData.SQLDebug 1
        
        // when
        NSString *path = [@"/conversations/" stringByAppendingPathComponent:conversation.identifier];
        ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
        
        // then
        XCTAssertNotNil(response);
        if (!response) {
            return;
        }
        XCTAssertEqual(response.HTTPStatus, 200);
        XCTAssertNil(response.transportSessionError);
        XCTAssertTrue([response.payload isKindOfClass:[NSDictionary class]]);
        NSDictionary *data = (id) response.payload;
        
        [self checkThatTransportData:data matchesConversation:conversation];
    }
}

- (void)testThatWeCanCreateAConversationWithAPostRequest
{
    
    // given
    __block MockUser *selfUser;
    __block MockUser *user1;
    __block MockUser *user2;
    __block NSString *user1ID;
    __block NSString *user2ID;
    
    __block MockConnection *connection1;
    __block MockConnection *connection2;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"The Great Quux"];
        user1 = [session insertUserWithName:@"Foo"];
        user1ID = user1.identifier;
        user2 = [session insertUserWithName:@"Bar"];
        user2ID = user2.identifier;
        
        connection1 = [session insertConnectionWithSelfUser:selfUser toUser:user1];
        connection1.status = @"accepted";
        connection1.lastUpdate = [NSDate dateWithTimeIntervalSince1970:1399920861.091];
        
        connection2 = [session insertConnectionWithSelfUser:selfUser toUser:user2];
        connection2.status = @"accepted";
        connection2.lastUpdate = [NSDate dateWithTimeIntervalSince1970:1399920861.098];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSDictionary *payload = @{ @"users": @[user1ID, user2ID] };
    
    ZMTransportResponse *response = [self responseForPayload:payload path:@"/conversations/" method:ZMMethodPOST];
    
    // then
    XCTAssertNotNil(response);
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertNil(response.transportSessionError);
    XCTAssertTrue([response.payload isKindOfClass:[NSDictionary class]]);
    
    NSDictionary *responsePayload = (id) response.payload;
    NSString *conversationID = [responsePayload stringForKey:@"id"];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", conversationID];
    NSFetchRequest *fetchRequest = [MockConversation sortedFetchRequestWithPredicate:predicate];
    [self.sut.managedObjectContext performBlockAndWait:^{
        NSArray *conversations = [self.sut.managedObjectContext executeFetchRequestOrAssert:fetchRequest];
        
        XCTAssertNotNil(conversations);
        XCTAssertEqual(1u, conversations.count);
        
        MockConversation *storedConversation = conversations[0];
        
        NSDictionary *expectedPayload = (NSDictionary *)[storedConversation transportData];
        XCTAssertEqualObjects(expectedPayload, responsePayload);
    }];
}

- (ZMTransportResponse *)responseForAddingMessageWithPayload:(NSDictionary *)payload path:(NSString *)path expectedEventType:(NSString *)expectedEventType
{
    // given
    
    __block MockUser *selfUser;
    __block MockUser *user1;
    
    __block MockConversation *oneOnOneConversation;
    __block NSString *selfUserID;
    __block NSString *oneOnOneConversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        selfUser.identifier = [[NSUUID createUUID] transportString];
        selfUserID = selfUser.identifier;
        user1 = [session insertUserWithName:@"Foo"];
        
        oneOnOneConversation = [session insertOneOnOneConversationWithSelfUser:selfUser otherUser:user1];
        oneOnOneConversationID = oneOnOneConversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSString *requestPath = [NSString pathWithComponents:@[@"/", @"conversations", oneOnOneConversationID, path]];
    ZMTransportResponse *response = [self responseForPayload:payload path:requestPath method:ZMMethodPOST];
    
    // then
    XCTAssertNotNil(response);
    if (!response) {
        return nil;
    }
    
    XCTAssertEqual(response.HTTPStatus, 201);
    XCTAssertNil(response.transportSessionError);
    
    XCTAssertTrue([response.payload isKindOfClass:[NSDictionary class]]);
    NSDictionary *responsePayload = [response.payload asDictionary];
    
    NSDictionary *messageRoundtripPayload = responsePayload;
    XCTAssertEqualObjects(responsePayload[@"conversation"], oneOnOneConversationID);
    XCTAssertEqualObjects(responsePayload[@"from"], selfUserID);
    XCTAssertEqualObjects(responsePayload[@"type"], expectedEventType);
    XCTAssertNotNil([responsePayload dateForKey:@"time"]);
    AssertDateIsRecent([responsePayload dateForKey:@"time"]);
    if ([[MockEvent persistentEvents] containsObject:@([MockEvent typeFromString:expectedEventType])]) {
        XCTAssertNotNil([responsePayload eventForKey:@"id"]);
    }
    
    path = [NSString pathWithComponents:@[@"/", @"conversations", oneOnOneConversationID, @"events?start=1.0&size=300"]];
    ZMTransportResponse *eventsResponse = [self responseForPayload:nil path:path method:ZMMethodGET];
    
    // then
    XCTAssertNotNil(eventsResponse);
    if (!eventsResponse) {
        return nil;
    }
    
    XCTAssertEqual(eventsResponse.HTTPStatus, 200);
    XCTAssertNil(eventsResponse.transportSessionError);
    NSArray *events = [[eventsResponse.payload asDictionary] arrayForKey:@"events"];
    XCTAssertNotNil(events);
    XCTAssertGreaterThanOrEqual(events.count, 1u);
    XCTAssertEqualObjects(events.lastObject, messageRoundtripPayload);
    
    return response;
}

- (void)testThatItAddsATextMessage
{
    //given
    NSString *messageText = @"Fofooof";
    NSUUID *nonce = [NSUUID createUUID];
    NSDictionary *payload = @{
                              @"content" : messageText,
                              @"nonce" : nonce.transportString
                              };
    
    NSString *path = @"messages";
    
    ZMTransportResponse *response = [self responseForAddingMessageWithPayload:payload path:path expectedEventType:@"conversation.message-add"];
    if (response != nil) {
        NSDictionary *data = [[response.payload asDictionary] dictionaryForKey:@"data"];

        XCTAssertNotNil(data);
        XCTAssertEqualObjects(data[@"content"], messageText);
        XCTAssertEqualObjects([data uuidForKey:@"nonce"], nonce);
    }
}

- (void)testThatItAddsAClientMessage
{
    NSString *messageText = @"Fofooof";
    ZMGenericMessage *message = [ZMGenericMessage messageWithText:messageText nonce:[NSUUID createUUID].transportString];
    NSString *base64Content = [message.data base64EncodedStringWithOptions:0];
    NSDictionary *payload = @{
                              @"content" : base64Content
                              };
    
    NSString *path = @"client-messages";
    ZMTransportResponse *response = [self responseForAddingMessageWithPayload:payload path:path expectedEventType:@"conversation.client-message-add"];
    if (response != nil) {
        NSString *data = [[response.payload asDictionary] stringForKey:@"data"];
        XCTAssertNotNil(data);
        XCTAssertEqualObjects(data, base64Content);
    }
}

- (void)testThatItReturnsMissingClientsWhenReceivingOTRMessage
{
    // given
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    __block MockUserClient *secondSelfClient;
    
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    __block MockUserClient *secondOtherUserClient;
    
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];
        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        
        selfClient = [selfUser.clients anyObject];
        secondSelfClient = [session registerClientForUser:selfUser label:@"self2" type:@"permanent"];
        
        otherUserClient = [otherUser.clients anyObject];
        secondOtherUserClient = [session registerClientForUser:otherUser label:@"other2" type:@"permanent"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    NSUInteger previousNotificationsCount = self.sut.generatedPushEvents.count;
    
    NSString *messageText = @"Fofooof";
    ZMGenericMessage *message = [ZMGenericMessage messageWithText:messageText nonce:[NSUUID createUUID].transportString];
    NSString *base64Content = [message.data base64EncodedStringWithOptions:0];
    
    NSString *redundantClientId = [NSString createAlphanumericalString];
    NSDictionary *payload = @{
                              @"sender": selfClient.identifier,
                              @"recipients" : @{
                                      otherUser.identifier: @{
                                              otherUserClient.identifier: base64Content,
                                              redundantClientId: base64Content
                                              }
                                      }
                              };
    
    // when
    NSString *requestPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.identifier, @"otr", @"messages"]];
    ZMTransportResponse *response = [self responseForPayload:payload path:requestPath method:ZMMethodPOST];
    
    XCTAssertNotNil(response);
    XCTAssertNil(response.transportSessionError);
    
    if (response != nil) {
        XCTAssertEqual(response.HTTPStatus, 412);
        
        NSDictionary *expectedResponsePayload = @{
                                                  @"missing": @{
                                                          selfUser.identifier: @[secondSelfClient.identifier],
                                                          otherUser.identifier: @[secondOtherUserClient.identifier]
                                                          },
                                                  @"redundant": @{
                                                          otherUser.identifier: @[redundantClientId]
                                                          }
                                                  };
        
        AssertEqualDictionaries(expectedResponsePayload[@"missing"], response.payload.asDictionary[@"missing"]);
        AssertEqualDictionaries(expectedResponsePayload[@"redundant"], response.payload.asDictionary[@"redundant"]);
    }
    
    XCTAssertEqual(self.sut.generatedPushEvents.count, previousNotificationsCount);
}

- (void)testThatItReturnsMissingClientsWhenReceivingOTRMessage_Protobuf
{
    // given
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    __block MockUserClient *secondSelfClient;
    
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    __block MockUserClient *secondOtherUserClient;
    
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];

        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        
        selfClient = [selfUser.clients anyObject];
        secondSelfClient = [session registerClientForUser:selfUser label:@"self2" type:@"permanent"];
        
        otherUserClient = [otherUser.clients anyObject];
        secondOtherUserClient = [session registerClientForUser:otherUser label:@"other2" type:@"permanent"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    NSUInteger previousNotificationsCount = self.sut.generatedPushEvents.count;
    
    NSString *messageText = @"Fofooof";
    ZMGenericMessage *message = [ZMGenericMessage messageWithText:messageText nonce:[NSUUID createUUID].transportString];
    
    NSString *redundantClientId = [NSString createAlphanumericalString];
    
    ZMNewOtrMessageBuilder *builder = [ZMNewOtrMessage builder];
    ZMClientIdBuilder *senderBuilder = [ZMClientId builder];
    
    unsigned long long senderId = 0;
    [[NSScanner scannerWithString:selfClient.identifier] scanHexLongLong:&senderId];
    
    [senderBuilder setClient:senderId];
    [builder setSender:[senderBuilder build]];
    
    ZMUserEntryBuilder *userEntryBuilder = [ZMUserEntry builder];
    ZMUserIdBuilder *userIdBuilder = [ZMUserId builder];
    [userIdBuilder setUuid:[[NSUUID uuidWithTransportString:otherUser.identifier] data]];
    [userEntryBuilder setUser:[userIdBuilder build]];
    
    NSArray *recipients = [@[otherUserClient.identifier, redundantClientId] mapWithBlock:^id(NSString *clientId) {
        
        ZMClientIdBuilder *recipientBuilder = [ZMClientId builder];
        
        unsigned long long recipientId = 0;
        [[NSScanner scannerWithString:clientId] scanHexLongLong:&recipientId];
        
        [recipientBuilder setClient:recipientId];
        
        ZMClientEntryBuilder *clientEntryBuilder = [ZMClientEntry builder];
        [clientEntryBuilder setClient:[recipientBuilder build]];
        [clientEntryBuilder setText:message.data];
        
        return [clientEntryBuilder build];
    }];
    
    [userEntryBuilder setClientsArray:recipients];
    ZMUserEntry *userEntry = [userEntryBuilder build];
    [builder setRecipientsArray:@[userEntry]];
    
    NSData *messageData = [[builder build] data];
    
    // when
    NSString *requestPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.identifier, @"otr", @"messages"]];
    ZMTransportResponse *response = [self responseForProtobufData:messageData path:requestPath method:ZMMethodPOST];
    
    // then
    XCTAssertNotNil(response);
    XCTAssertNil(response.transportSessionError);
    
    if (response != nil) {
        XCTAssertEqual(response.HTTPStatus, 412);
        
        NSDictionary *expectedResponsePayload = @{
                                                  @"missing": @{
                                                          selfUser.identifier: @[secondSelfClient.identifier],
                                                          otherUser.identifier: @[secondOtherUserClient.identifier]
                                                          },
                                                  @"redundant": @{
                                                          otherUser.identifier: @[redundantClientId]
                                                          }
                                                  };
        
        AssertEqualDictionaries(expectedResponsePayload[@"missing"], response.payload.asDictionary[@"missing"]);
        AssertEqualDictionaries(expectedResponsePayload[@"redundant"], response.payload.asDictionary[@"redundant"]);
    }
    
    XCTAssertEqual(self.sut.generatedPushEvents.count, previousNotificationsCount);
}

- (void)testThatItReturnsMissingAndRedundantClientsWhenReceivingOTRAsset
{
    // given
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    __block MockUserClient *secondSelfClient;
    
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    __block MockUserClient *secondOtherUserClient;
    
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];
        
        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        
        selfClient = [selfUser.clients anyObject];
        secondSelfClient = [session registerClientForUser:selfUser label:@"self2" type:@"permanent"];
        
        otherUserClient = [otherUser.clients anyObject];
        secondOtherUserClient = [session registerClientForUser:otherUser label:@"other2" type:@"permanent"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    NSUInteger previousNotificationsCount = self.sut.generatedPushEvents.count;
    
    NSData *imageData = [self verySmallJPEGData];
    ZMGenericMessage *message = [ZMGenericMessage messageWithImageData:imageData format:ZMImageFormatMedium nonce:[NSUUID createUUID].transportString];
    NSString *base64Content = [message.data base64EncodedStringWithOptions:0];
    
    NSString *redundantClientId = [NSString createAlphanumericalString];
    NSDictionary *payload = @{
                              @"info": base64Content,
                              @"sender": selfClient.identifier,
                              @"recipients" : @{
                                      otherUser.identifier: @{
                                              otherUserClient.identifier: base64Content,
                                              redundantClientId: base64Content
                                              }
                                      }
                              };
    
    // when
    NSString *requestPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.identifier, @"otr", @"assets"]];
    ZMTransportResponse *response = [self responseForImageData:imageData contentDisposition:payload path:requestPath];
    
    // then
    XCTAssertNotNil(response);
    XCTAssertNil(response.transportSessionError);
    
    if (response != nil) {
        XCTAssertEqual(response.HTTPStatus, 412);
        
        NSDictionary *expectedResponsePayload = @{
                                                  @"missing": @{
                                                          selfUser.identifier: @[secondSelfClient.identifier],
                                                          otherUser.identifier: @[secondOtherUserClient.identifier]
                                                          },
                                                  @"redundant": @{
                                                          otherUser.identifier: @[redundantClientId]
                                                          }
                                                  };
        
        AssertEqualDictionaries(expectedResponsePayload[@"missing"], response.payload.asDictionary[@"missing"]);
        AssertEqualDictionaries(expectedResponsePayload[@"redundant"], response.payload.asDictionary[@"redundant"]);
    }
    
    XCTAssertEqual(self.sut.generatedPushEvents.count, previousNotificationsCount);
}


- (void)testThatItReturnsMissingAndRedundantClientsWhenReceivingOTRAsset_Protobuf
{
    // given
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    __block MockUserClient *secondSelfClient;
    
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    __block MockUserClient *secondOtherUserClient;
    
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];

        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        
        selfClient = [selfUser.clients anyObject];
        secondSelfClient = [session registerClientForUser:selfUser label:@"self2" type:@"permanent"];
        
        otherUserClient = [otherUser.clients anyObject];
        secondOtherUserClient = [session registerClientForUser:otherUser label:@"other2" type:@"permanent"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    NSUInteger previousNotificationsCount = self.sut.generatedPushEvents.count;
    
    NSData *imageData = [self verySmallJPEGData];
    ZMGenericMessage *message = [ZMGenericMessage messageWithImageData:imageData format:ZMImageFormatMedium nonce:[NSUUID createUUID].transportString];
    NSString *redundantClientId = [NSString createAlphanumericalString];
    
    ZMOtrAssetMetaBuilder *builder = [ZMOtrAssetMeta builder];
    ZMClientIdBuilder *senderBuilder = [ZMClientId builder];
    
    unsigned long long senderId = 0;
    [[NSScanner scannerWithString:selfClient.identifier] scanHexLongLong:&senderId];
    
    [senderBuilder setClient:senderId];
    [builder setSender:[senderBuilder build]];
    [builder setIsInline:NO];
    
    ZMUserEntryBuilder *userEntryBuilder = [ZMUserEntry builder];
    ZMUserIdBuilder *userIdBuilder = [ZMUserId builder];
    [userIdBuilder setUuid:[[NSUUID uuidWithTransportString:otherUser.identifier] data]];
    [userEntryBuilder setUser:[userIdBuilder build]];
    
    NSArray *recipients = [@[otherUserClient.identifier, redundantClientId] mapWithBlock:^id(NSString *clientId) {

        ZMClientIdBuilder *recipientBuilder = [ZMClientId builder];
        
        unsigned long long recipientId = 0;
        [[NSScanner scannerWithString:clientId] scanHexLongLong:&recipientId];
        
        [recipientBuilder setClient:recipientId];
        
        ZMClientEntryBuilder *clientEntryBuilder = [ZMClientEntry builder];
        [clientEntryBuilder setClient:[recipientBuilder build]];
        [clientEntryBuilder setText:message.data];
        
        return [clientEntryBuilder build];
    }];
    
    [userEntryBuilder setClientsArray:recipients];
    ZMUserEntry *userEntry = [userEntryBuilder build];
    [builder setRecipientsArray:@[userEntry]];
    
    NSData *messageData = [[builder build] data];
    
    // when
    NSString *requestPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.identifier, @"otr", @"assets"]];
    ZMTransportResponse *response = [self responseForImageData:imageData metaData:messageData imageMediaType:@"image/jpeg" path:requestPath];
    
    // then
    XCTAssertNotNil(response);
    XCTAssertNil(response.transportSessionError);
    
    if (response != nil) {
        XCTAssertEqual(response.HTTPStatus, 412);
        
        NSDictionary *expectedResponsePayload = @{
                                                  @"missing": @{
                                                          selfUser.identifier: @[secondSelfClient.identifier],
                                                          otherUser.identifier: @[secondOtherUserClient.identifier]
                                                          },
                                                  @"redundant": @{
                                                          otherUser.identifier: @[redundantClientId]
                                                          }
                                                  };
        
        AssertEqualDictionaries(expectedResponsePayload[@"missing"], response.payload.asDictionary[@"missing"]);
        AssertEqualDictionaries(expectedResponsePayload[@"redundant"], response.payload.asDictionary[@"redundant"]);
    }
    
    XCTAssertEqual(self.sut.generatedPushEvents.count, previousNotificationsCount);
}

- (void)testThatItCreatesPushEventsWhenReceivingOTRMessageWithoutMissedClients
{
    // given
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    __block MockUserClient *secondSelfClient;
    
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    __block MockUserClient *secondOtherUserClient;
    
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];

        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        
        selfClient = [selfUser.clients anyObject];
        secondSelfClient = [session registerClientForUser:selfUser label:@"self2" type:@"permanent"];
        
        otherUserClient = [otherUser.clients anyObject];
        secondOtherUserClient = [session registerClientForUser:otherUser label:@"other2" type:@"permanent"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    NSUInteger previousNotificationsCount = self.sut.generatedPushEvents.count;
    
    NSString *messageText = @"Fofooof";
    ZMGenericMessage *message = [ZMGenericMessage messageWithText:messageText nonce:[NSUUID createUUID].transportString];
    NSString *base64Content = [message.data base64EncodedStringWithOptions:0];
    
    NSString *redundantClientId = [NSString createAlphanumericalString];
    NSDictionary *payload = @{
                              @"sender": selfClient.identifier,
                              @"recipients" : @{
                                      selfUser.identifier: @{
                                              secondSelfClient.identifier: base64Content
                                              },
                                      otherUser.identifier: @{
                                              otherUserClient.identifier: base64Content,
                                              secondOtherUserClient.identifier: base64Content,
                                              redundantClientId: base64Content
                                              }
                                      }
                              };
    
    // when
    NSString *requestPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.identifier, @"otr", @"messages"]];
    ZMTransportResponse *response = [self responseForPayload:payload path:requestPath method:ZMMethodPOST];
    
    // then
    XCTAssertNotNil(response);
    XCTAssertNil(response.transportSessionError);
    
    if (response != nil) {
        XCTAssertEqual(response.HTTPStatus, 201);
        
        NSDictionary *expectedResponsePayload = @{
                                                  @"missing": @{},
                                                  @"redundant": @{
                                                          otherUser.identifier: @[redundantClientId]
                                                          }
                                                  };
        
        AssertEqualDictionaries(expectedResponsePayload[@"missing"], response.payload.asDictionary[@"missing"]);
        AssertEqualDictionaries(expectedResponsePayload[@"redundant"], response.payload.asDictionary[@"redundant"]);
    }
    
    XCTAssertEqual(self.sut.generatedPushEvents.count, previousNotificationsCount+3u);
    if (self.sut.generatedPushEvents.count > 4u) {
        NSArray *otrEvents = [self.sut.generatedPushEvents subarrayWithRange:NSMakeRange(self.sut.generatedPushEvents.count-3, 3)];
        for (MockPushEvent *event in otrEvents) {
            NSDictionary *eventPayload = event.payload.asDictionary;
            XCTAssertEqualObjects(eventPayload[@"type"], @"conversation.otr-message-add");
        }
    }
}

- (void)testThatItCreatesPushEventsWhenReceivingOTRMessageWithoutMissedClients_Protobuf
{
    // given
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    __block MockUserClient *secondSelfClient;
    
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    __block MockUserClient *secondOtherUserClient;
    
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];

        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        
        selfClient = [selfUser.clients anyObject];
        secondSelfClient = [session registerClientForUser:selfUser label:@"self2" type:@"permanent"];
        
        otherUserClient = [otherUser.clients anyObject];
        secondOtherUserClient = [session registerClientForUser:otherUser label:@"other2" type:@"permanent"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    NSUInteger previousNotificationsCount = self.sut.generatedPushEvents.count;
    
    NSString *messageText = @"Fofooof";
    ZMGenericMessage *message = [ZMGenericMessage messageWithText:messageText nonce:[NSUUID createUUID].transportString];
    
    NSString *redundantClientId = [NSString createAlphanumericalString];
    
    ZMNewOtrMessageBuilder *builder = [ZMNewOtrMessage builder];
    ZMClientIdBuilder *senderBuilder = [ZMClientId builder];
    
    unsigned long long senderId = 0;
    [[NSScanner scannerWithString:selfClient.identifier] scanHexLongLong:&senderId];
    
    [senderBuilder setClient:senderId];
    [builder setSender:[senderBuilder build]];
    
    NSDictionary *usersToClients = @{
                                     selfUser.identifier: @[secondSelfClient.identifier],
                                     otherUser.identifier: @[otherUserClient.identifier, secondOtherUserClient.identifier, redundantClientId]
                                     };
    
    for (NSString *userId in usersToClients) {
        
        NSArray *recipients = [(NSArray *)usersToClients[userId] mapWithBlock:^id(NSString *clientId) {
            
            ZMClientIdBuilder *recipientBuilder = [ZMClientId builder];
            
            unsigned long long recipientId = 0;
            [[NSScanner scannerWithString:clientId] scanHexLongLong:&recipientId];
            
            [recipientBuilder setClient:recipientId];
            
            ZMClientEntryBuilder *clientEntryBuilder = [ZMClientEntry builder];
            [clientEntryBuilder setClient:[recipientBuilder build]];
            [clientEntryBuilder setText:message.data];
            
            return [clientEntryBuilder build];
        }];
        
        ZMUserEntryBuilder *userEntryBuilder = [ZMUserEntry builder];
        ZMUserIdBuilder *userIdBuilder = [ZMUserId builder];
        [userIdBuilder setUuid:[[NSUUID uuidWithTransportString:userId] data]];
        [userEntryBuilder setUser:[userIdBuilder build]];

        [userEntryBuilder setClientsArray:recipients];
        ZMUserEntry *userEntry = [userEntryBuilder build];
        
        [builder addRecipients:userEntry];
    }
    
    NSData *messageData = [[builder build] data];

    // when
    NSString *requestPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.identifier, @"otr", @"messages"]];
    ZMTransportResponse *response = [self responseForProtobufData:messageData path:requestPath method:ZMMethodPOST];
    
    // then
    XCTAssertNotNil(response);
    XCTAssertNil(response.transportSessionError);
    
    if (response != nil) {
        XCTAssertEqual(response.HTTPStatus, 201);
        
        NSDictionary *expectedResponsePayload = @{
                                                  @"missing": @{},
                                                  @"redundant": @{
                                                          otherUser.identifier: @[redundantClientId]
                                                          }
                                                  };
        
        AssertEqualDictionaries(expectedResponsePayload[@"missing"], response.payload.asDictionary[@"missing"]);
        AssertEqualDictionaries(expectedResponsePayload[@"redundant"], response.payload.asDictionary[@"redundant"]);
    }
    
    XCTAssertEqual(self.sut.generatedPushEvents.count, previousNotificationsCount+3u);
    if (self.sut.generatedPushEvents.count > 4u) {
        NSArray *otrEvents = [self.sut.generatedPushEvents subarrayWithRange:NSMakeRange(self.sut.generatedPushEvents.count-3, 3)];
        for (MockPushEvent *event in otrEvents) {
            NSDictionary *eventPayload = event.payload.asDictionary;
            XCTAssertEqualObjects(eventPayload[@"type"], @"conversation.otr-message-add");
        }
    }
}


- (void)testThatItCreatesPushEventsWhenReceivingOTRAssetWithoutMissedClients
{
    // given
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    __block MockUserClient *secondSelfClient;
    
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    __block MockUserClient *secondOtherUserClient;
    
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];

        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        
        selfClient = [selfUser.clients anyObject];
        secondSelfClient = [session registerClientForUser:selfUser label:@"self2" type:@"permanent"];
        
        otherUserClient = [otherUser.clients anyObject];
        secondOtherUserClient = [session registerClientForUser:otherUser label:@"other2" type:@"permanent"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    NSUInteger previousNotificationsCount = self.sut.generatedPushEvents.count;

    NSData *imageData = [self verySmallJPEGData];
    ZMGenericMessage *message = [ZMGenericMessage messageWithImageData:imageData format:ZMImageFormatMedium nonce:[NSUUID createUUID].transportString];
    NSString *base64Content = [message.data base64EncodedStringWithOptions:0];
    
    NSString *redundantClientId = [NSString createAlphanumericalString];
    NSDictionary *payload = @{
                              @"info": base64Content,
                              @"sender": selfClient.identifier,
                              @"recipients" : @{
                                      selfUser.identifier: @{
                                              secondSelfClient.identifier: base64Content
                                              },
                                      otherUser.identifier: @{
                                              otherUserClient.identifier: base64Content,
                                              secondOtherUserClient.identifier: base64Content,
                                              redundantClientId: base64Content
                                              }
                                      }
                              };
    
    // when
    NSString *requestPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.identifier, @"otr", @"assets"]];
    ZMTransportResponse *response = [self responseForImageData:imageData contentDisposition:payload path:requestPath];
    
    // then
    XCTAssertNotNil(response);
    XCTAssertNil(response.transportSessionError);
    
    if (response != nil) {
        XCTAssertEqual(response.HTTPStatus, 201);
        
        NSDictionary *expectedResponsePayload = @{
                                                  @"missing": @{},
                                                  @"redundant": @{
                                                          otherUser.identifier: @[redundantClientId]
                                                          }
                                                  };
        
        AssertEqualDictionaries(expectedResponsePayload[@"missing"], response.payload.asDictionary[@"missing"]);
        AssertEqualDictionaries(expectedResponsePayload[@"redundant"], response.payload.asDictionary[@"redundant"]);
    }
    
    XCTAssertEqual(self.sut.generatedPushEvents.count, previousNotificationsCount+3u);
    if (self.sut.generatedPushEvents.count > 4u) {
        NSArray *otrEvents = [self.sut.generatedPushEvents subarrayWithRange:NSMakeRange(self.sut.generatedPushEvents.count-3, 3)];
        for (MockPushEvent *event in otrEvents) {
            NSDictionary *eventPayload = event.payload.asDictionary;
            XCTAssertEqualObjects(eventPayload[@"type"], @"conversation.otr-asset-add");
        }
    }
}

- (void)testThatItCreatesPushEventsWhenReceivingEncryptedOTRMessageWithCorrectData;
{
    // given
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];
        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        
        selfClient = [selfUser.clients anyObject];
        otherUserClient = [otherUser.clients anyObject];
        
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSUUID *nonce = [NSUUID createUUID];
    ZMGenericMessage *message = [ZMGenericMessage messageWithText:@"Je suis kaput" nonce:nonce.transportString];
    NSString *base64Content = [message.data base64EncodedStringWithOptions:0];
    
    // when
    [self.sut performRemoteChanges:^(__unused MockTransportSession<MockTransportSessionObjectCreation> *session) {
        NSData *encryptedData = [MockUserClient encryptedDataFromClient:otherUserClient toClient:selfClient data:message.data];
        [conversation insertOTRMessageFromClient:otherUserClient toClient:selfClient data:encryptedData];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    MockPushEvent *lastEvent = self.sut.generatedPushEvents.lastObject;
    NSDictionary *lastEventPayload = [lastEvent.payload asDictionary];
    XCTAssertEqualObjects(lastEventPayload[@"type"], @"conversation.otr-message-add");
    XCTAssertEqualObjects(lastEventPayload[@"data"][@"recipient"], selfClient.identifier);
    XCTAssertEqualObjects(lastEventPayload[@"data"][@"sender"], otherUserClient.identifier);
    XCTAssertNotEqualObjects(lastEventPayload[@"data"][@"text"], base64Content);
}

- (void)testThatItCreatesPushEventsWhenReceivingEncryptedOTRAssetWithCorrectData;
{
    // given
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];
        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        
        selfClient = [selfUser.clients anyObject];
        otherUserClient = [otherUser.clients anyObject];
        
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSUUID *nonce = [NSUUID createUUID];
    NSUUID *assetID = [NSUUID createUUID];
    NSData *imageData = [self verySmallJPEGData];
    
    ZMGenericMessage *message = [ZMGenericMessage  messageWithImageData:imageData format:ZMImageFormatMedium nonce:nonce.transportString];
    NSString *base64Content = [message.data base64EncodedStringWithOptions:0];
    // when
    [self.sut performRemoteChanges:^(__unused MockTransportSession<MockTransportSessionObjectCreation> *session) {
        NSData *encryptedData = [MockUserClient encryptedDataFromClient:otherUserClient toClient:selfClient data:message.data];
        [conversation  insertOTRAssetFromClient:otherUserClient toClient:selfClient metaData:encryptedData imageData:imageData assetId:assetID isInline:YES];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    MockPushEvent *lastEvent = self.sut.generatedPushEvents.lastObject;
    NSDictionary *lastEventPayload = [lastEvent.payload asDictionary];
    XCTAssertEqualObjects(lastEventPayload[@"type"], @"conversation.otr-asset-add");
    XCTAssertEqualObjects(lastEventPayload[@"data"][@"recipient"], selfClient.identifier);
    XCTAssertEqualObjects(lastEventPayload[@"data"][@"sender"], otherUserClient.identifier);
    XCTAssertEqualObjects(lastEventPayload[@"data"][@"data"], [imageData base64String]);
    XCTAssertNotEqualObjects(lastEventPayload[@"data"][@"key"], base64Content);
}

- (void)testThatItReturnsAValidResponseWenUploadingAFile
{
    // given
    __block MockConversation *conversation;
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];
        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        selfClient = [selfUser.clients anyObject];
        otherUserClient = [otherUser.clients anyObject];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    NSData *fileData = [NSData secureRandomDataOfLength:256];
    ZMOtrAssetMeta *metaData = [self OTRAssetMetaWithSender:selfClient recipients:@[otherUser] text:[NSData secureRandomDataOfLength:16]];
    NSUInteger previousNotificationsCount = self.sut.generatedPushEvents.count;
    NSString *requestPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.identifier, @"otr", @"assets"]];
    ZMTransportResponse *response = [self responseForFileData:fileData path:requestPath metadata:metaData.data contentType:@"multipart/mixed"];
    
    // then
    XCTAssertNotNil(response);
    XCTAssertNil(response.transportSessionError);
    
    if (response != nil) {
        XCTAssertEqual(response.HTTPStatus, 201);
        AssertEqualDictionaries(@{}, response.payload.asDictionary[@"missing"]);
        AssertEqualDictionaries(@{}, response.payload.asDictionary[@"redundant"]);
    }
    
    XCTAssertEqual(self.sut.generatedPushEvents.count, previousNotificationsCount + 1u);
}

- (ZMOtrAssetMeta *)OTRAssetMetaWithSender:(MockUserClient *)sender recipients:(NSArray <MockUser *>*)recipients text:(NSData *)text
{
    ZMOtrAssetMetaBuilder *builder = ZMOtrAssetMeta.builder;
    ZMClientIdBuilder *senderIDBuilder = ZMClientId.builder;
    
    NSArray <ZMUserEntry *>* userEntries = [recipients mapWithBlock:^ZMUserEntry *(MockUser *user) {
        ZMUserEntryBuilder *entryBuilder = ZMUserEntry.builder;
        ZMUserIdBuilder *userIDBuilder = ZMUserId.builder;
        [userIDBuilder setUuid:[NSUUID uuidWithTransportString:user.identifier].data];
        entryBuilder.user = userIDBuilder.build;
        [entryBuilder setClientsArray:[user.clients.allObjects mapWithBlock:^ZMClientEntry *(MockUserClient *client) {
            ZMClientEntryBuilder *clientBuilder = ZMClientEntry.builder;
            ZMClientIdBuilder *clientIDBuilder = ZMClientId.builder;
            unsigned long long hexID;
            [[NSScanner scannerWithString:client.identifier] scanHexLongLong:&hexID];
            [clientIDBuilder setClient:hexID];
            [clientBuilder setClient:clientIDBuilder.build];
            [clientBuilder setText:text];
            return clientBuilder.build;
        }]];
        
        return entryBuilder.build;
    }];
    
    [builder setRecipientsArray:userEntries];
    builder.isInline = NO;
    builder.nativePush = YES;

    unsigned long long hexID;
    [[NSScanner scannerWithString:sender.identifier] scanHexLongLong:&hexID];
    [senderIDBuilder setClient:hexID];
    builder.sender = senderIDBuilder.build;
    return builder.build;
}

- (void)testThatItCreatesPushEventsWhenReceivingOTRAssetWithoutMissedClients_Protobuf
{
    // given
    __block MockUser *selfUser;
    __block MockUserClient *selfClient;
    __block MockUserClient *secondSelfClient;
    
    __block MockUser *otherUser;
    __block MockUserClient *otherUserClient;
    __block MockUserClient *secondOtherUserClient;
    
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"foo"];
        [session registerClientForUser:selfUser label:@"self user" type:@"permanent"];
        otherUser = [session insertUserWithName:@"bar"];
        conversation = [session insertConversationWithCreator:selfUser otherUsers:@[otherUser] type:ZMTConversationTypeOneOnOne];
        
        selfClient = [selfUser.clients anyObject];
        secondSelfClient = [session registerClientForUser:selfUser label:@"self2" type:@"permanent"];
        
        otherUserClient = [otherUser.clients anyObject];
        secondOtherUserClient = [session registerClientForUser:otherUser label:@"other2" type:@"permanent"];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    NSUInteger previousNotificationsCount = self.sut.generatedPushEvents.count;
    
    NSData *imageData = [self verySmallJPEGData];
    ZMGenericMessage *message = [ZMGenericMessage messageWithImageData:imageData format:ZMImageFormatMedium nonce:[NSUUID createUUID].transportString];
    
    NSString *redundantClientId = [NSString createAlphanumericalString];
    
    ZMOtrAssetMetaBuilder *builder = [ZMOtrAssetMeta builder];
    ZMClientIdBuilder *senderBuilder = [ZMClientId builder];
    
    unsigned long long senderId = 0;
    [[NSScanner scannerWithString:selfClient.identifier] scanHexLongLong:&senderId];
    
    [senderBuilder setClient:senderId];
    [builder setSender:[senderBuilder build]];
    
    NSDictionary *usersToClients = @{
                                     selfUser.identifier: @[secondSelfClient.identifier],
                                     otherUser.identifier: @[otherUserClient.identifier, secondOtherUserClient.identifier, redundantClientId]
                                     };
    
    for (NSString *userId in usersToClients) {
        
        NSArray *recipients = [(NSArray *)usersToClients[userId] mapWithBlock:^id(NSString *clientId) {
            
            ZMClientIdBuilder *recipientBuilder = [ZMClientId builder];
            
            unsigned long long recipientId = 0;
            [[NSScanner scannerWithString:clientId] scanHexLongLong:&recipientId];
            
            [recipientBuilder setClient:recipientId];
            
            ZMClientEntryBuilder *clientEntryBuilder = [ZMClientEntry builder];
            [clientEntryBuilder setClient:[recipientBuilder build]];
            [clientEntryBuilder setText:message.data];
            
            return [clientEntryBuilder build];
        }];
        
        ZMUserEntryBuilder *userEntryBuilder = [ZMUserEntry builder];
        ZMUserIdBuilder *userIdBuilder = [ZMUserId builder];
        [userIdBuilder setUuid:[[NSUUID uuidWithTransportString:userId] data]];
        [userEntryBuilder setUser:[userIdBuilder build]];
        
        [userEntryBuilder setClientsArray:recipients];
        ZMUserEntry *userEntry = [userEntryBuilder build];
        
        [builder addRecipients:userEntry];
    }
    
    NSData *messageData = [[builder build] data];
    
    // when
    NSString *requestPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.identifier, @"otr", @"assets"]];
    ZMTransportResponse *response = [self responseForImageData:imageData metaData:messageData imageMediaType:@"image/jpeg" path:requestPath];
    
    // then
    XCTAssertNotNil(response);
    XCTAssertNil(response.transportSessionError);
    
    if (response != nil) {
        XCTAssertEqual(response.HTTPStatus, 201);
        
        NSDictionary *expectedResponsePayload = @{
                                                  @"missing": @{},
                                                  @"redundant": @{
                                                          otherUser.identifier: @[redundantClientId]
                                                          }
                                                  };
        
        AssertEqualDictionaries(expectedResponsePayload[@"missing"], response.payload.asDictionary[@"missing"]);
        AssertEqualDictionaries(expectedResponsePayload[@"redundant"], response.payload.asDictionary[@"redundant"]);
    }
    
    XCTAssertEqual(self.sut.generatedPushEvents.count, previousNotificationsCount+3u);
    if (self.sut.generatedPushEvents.count > 4u) {
        NSArray *otrEvents = [self.sut.generatedPushEvents subarrayWithRange:NSMakeRange(self.sut.generatedPushEvents.count-3, 3)];
        for (MockPushEvent *event in otrEvents) {
            NSDictionary *eventPayload = event.payload.asDictionary;
            XCTAssertEqualObjects(eventPayload[@"type"], @"conversation.otr-asset-add");
        }
    }
}

- (void)testThatInsertingArbitraryEventWithBlock:(MockEvent *(^)(MockTransportSession<MockTransportSessionObjectCreation> *session, MockConversation *conversation))eventBlock expectedPayloadData:(id<ZMTransportData>)expectedPayloadData
{
    // given
    __block MockUser *selfUser;
    
    __block MockConversation *conversation;
    __block MockEvent *event;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        [session registerClientForUser:selfUser label:@"Self Client" type:@"permanent"];
        conversation = [session insertSelfConversationWithSelfUser:selfUser];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // when
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> * session) {
        event = eventBlock(session, conversation);
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    [self.sut.managedObjectContext performBlockAndWait:^{
        XCTAssertNotNil(event);
        if ([[MockEvent persistentEvents] containsObject:@(event.eventType)]) {
            XCTAssertNotNil(event.identifier);
            XCTAssertEqualObjects(conversation.lastEvent, event.identifier);
        }
        XCTAssertEqual(event.from, selfUser);
        XCTAssertEqualObjects(event.conversation, conversation);
        XCTAssertEqualObjects(conversation.lastEventTime, event.time);
        XCTAssertEqualObjects(event.data, [expectedPayloadData asTransportData]);
    }];
}

- (void)testThatInsertEventInConversationSetsProperValues
{
    NSString *newConversationName = @"¡Ay caramba!";
    NSDictionary *expectedPayloadData = @{@"name": newConversationName};
    
    [self testThatInsertingArbitraryEventWithBlock:^MockEvent *(MockTransportSession<MockTransportSessionObjectCreation> *session, MockConversation *conversation) {
        return [conversation changeNameByUser:session.selfUser name:@"¡Ay caramba!"];
    } expectedPayloadData:expectedPayloadData];
}

- (void)testThatInsertTextMessageInConversationSetsProperValues
{
    NSUUID *nonce = [NSUUID createUUID];
    NSString *text = [self.name stringByAppendingString:@" message 12534"];
    NSDictionary *expectedPayloadData = @{@"nonce":nonce.transportString,@"content":text};
    
    [self testThatInsertingArbitraryEventWithBlock:^MockEvent *(MockTransportSession<MockTransportSessionObjectCreation> *session, MockConversation *conversation) {
        return [conversation insertTextMessageFromUser:session.selfUser text:text nonce:nonce];
    } expectedPayloadData:expectedPayloadData];
}

- (void)testThatInsertClientMessageInConversationSetsProperValues
{
    NSString *text = [self.name stringByAppendingString:@" message 12534"];
    ZMGenericMessage *message = [ZMGenericMessage messageWithText:text nonce:[NSUUID createUUID].transportString];
    NSData *data = message.data;
    id<ZMTransportData> expectedPayloadData = [data base64EncodedStringWithOptions:0];
    
    [self testThatInsertingArbitraryEventWithBlock:^MockEvent *(MockTransportSession<MockTransportSessionObjectCreation> *session, MockConversation *conversation) {
        return [conversation insertClientMessageFromUser:session.selfUser data:data];
    } expectedPayloadData:expectedPayloadData];
}

- (void)testThatInsertOTRMessageInConversationSetsProperValues
{
    NSString *text = [self.name stringByAppendingString:@" message 12534"];
    ZMGenericMessage *message = [ZMGenericMessage messageWithText:text nonce:[NSUUID createUUID].transportString];
    NSData *data = message.data;
    __block NSMutableDictionary *expectedPayloadData = [@{@"text": [data base64EncodedStringWithOptions:0]} mutableCopy];
    
    [self testThatInsertingArbitraryEventWithBlock:^MockEvent *(MockTransportSession<MockTransportSessionObjectCreation> *session, MockConversation *conversation) {
        MockUserClient *client1 = [session registerClientForUser:session.selfUser label:@"client1" type:@"permanent"];
        MockUserClient *client2 = [session registerClientForUser:session.selfUser label:@"client2" type:@"permanent"];
        expectedPayloadData[@"sender"] = client1.identifier;
        expectedPayloadData[@"recipient"] = client2.identifier;
        return [conversation insertOTRMessageFromClient:client1 toClient:client2 data:data];
    } expectedPayloadData:expectedPayloadData];
}

- (void)testThatInsertNotInlineOTRAssetInConversationSetsProperValues
{
    NSData *mediumData = [self verySmallJPEGData];
    ZMGenericMessage *message = [ZMGenericMessage messageWithImageData:mediumData format:ZMImageFormatMedium nonce:[NSUUID createUUID].transportString];
    
    NSData *info = message.data;
    NSData *imageData = [@"image" dataUsingEncoding:NSUTF8StringEncoding];
    
    NSUUID *assetId = [NSUUID createUUID];
    __block NSMutableDictionary *expectedPayloadData = [@{@"data": [NSNull null],
                                                          @"key": [info base64EncodedStringWithOptions:0],
                                                          @"id": assetId.transportString} mutableCopy];
    
    [self testThatInsertingArbitraryEventWithBlock:^MockEvent *(MockTransportSession<MockTransportSessionObjectCreation> *session, MockConversation *conversation) {
        MockUserClient *client1 = [session registerClientForUser:session.selfUser label:@"client1" type:@"permanent"];
        MockUserClient *client2 = [session registerClientForUser:session.selfUser label:@"client2" type:@"permanent"];
        expectedPayloadData[@"sender"] = client1.identifier;
        expectedPayloadData[@"recipient"] = client2.identifier;
        
        return [conversation insertOTRAssetFromClient:client1 toClient:client2 metaData:info imageData:imageData assetId:assetId isInline:NO];
    } expectedPayloadData:expectedPayloadData];
}

- (void)testThatInsertInlineOTRAssetInConversationSetsProperValues
{
    NSData *mediumData = [self verySmallJPEGData];
    ZMGenericMessage *message = [ZMGenericMessage messageWithImageData:mediumData format:ZMImageFormatPreview nonce:[NSUUID createUUID].transportString];
    
    NSData *info = message.data;
    NSData *imageData = [@"image" dataUsingEncoding:NSUTF8StringEncoding];
    
    NSUUID *assetId = [NSUUID createUUID];
    __block NSMutableDictionary *expectedPayloadData = [@{@"data": [imageData base64EncodedStringWithOptions:0],
                                                          @"key": [info base64EncodedStringWithOptions:0],
                                                          @"id": assetId.transportString} mutableCopy];
    
    [self testThatInsertingArbitraryEventWithBlock:^MockEvent *(MockTransportSession<MockTransportSessionObjectCreation> *session, MockConversation *conversation) {
        MockUserClient *client1 = [session.selfUser.clients anyObject];
        MockUserClient *client2 = [session registerClientForUser:session.selfUser label:@"client2" type:@"permanent"];
        expectedPayloadData[@"sender"] = client1.identifier;
        expectedPayloadData[@"recipient"] = client2.identifier;
        
        return [conversation insertOTRAssetFromClient:client1 toClient:client2 metaData:info imageData:imageData assetId:assetId isInline:YES];
    } expectedPayloadData:expectedPayloadData];
}

- (void)testThatItInsertingACallEndedEventSetsCorrectValues
{
    NSDictionary *expectedPayloadData = @{@"reason":@"missed"};
    
    [self testThatInsertingArbitraryEventWithBlock:^MockEvent *(MockTransportSession<MockTransportSessionObjectCreation> *session, MockConversation *conversation) {
        return [conversation callEndedEventFromUser:session.selfUser selfUser:session.selfUser];
    } expectedPayloadData:expectedPayloadData];
}

- (void)testThatItAddsTwoImageEventsToTheConversation
{
    // given
    __block MockConversation *conversation;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        MockUser *selfUser = [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:selfUser];
        
        // when
        [conversation insertImageEventsFromUser:selfUser];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    [self.sut.managedObjectContext performBlockAndWait:^{
        XCTAssertNotNil(conversation.events);
        XCTAssertNotEqual([conversation.events indexOfObjectPassingTest:^BOOL(MockEvent *event, NSUInteger idx, BOOL *stop) {
            NOT_USED(idx);
            NOT_USED(stop);
            
            if (! [event.type isEqualToString:@"conversation.asset-add"]) {
                return NO;
            }
            
            NSDictionary *info = event.data[@"info"];
            if (! [info[@"tag"] isEqualToString:@"preview"]) {
                return NO;
            }
            
            return YES;
        }], (NSUInteger) NSNotFound);
        
        
        
        XCTAssertNotEqual([conversation.events indexOfObjectPassingTest:^BOOL(MockEvent *event, NSUInteger idx, BOOL *stop) {
            NOT_USED(idx);
            NOT_USED(stop);
            
            if (! [event.type isEqualToString:@"conversation.asset-add"]) {
                return NO;
            }
            
            NSDictionary *info = event.data[@"info"];
            if (! [info[@"tag"] isEqualToString:@"medium"]) {
                return NO;
            }
            
            return YES;
        }], (NSUInteger) NSNotFound);
    }];
}

- (ZMTransportResponse *)checkThatItInsertsAnEventsWhenPostingPreviewImageToAConversation:(MockConversation *)conversation path:(NSString *)path data:(NSData *)data isInline:(BOOL)isInline
{
    __block NSOrderedSet *eventsStart;
    [self.sut.managedObjectContext performBlockAndWait:^{
        eventsStart = [conversation.events copy];
    }];
    
    // when
    NSString * const MD5String = [[data zmMD5Digest] base64EncodedStringWithOptions:0];
    NSUUID * const correlationIdentifier = [NSUUID createUUID];
    CGSize const originalSize = CGSizeMake(1900, 1500);
    NSDictionary * const disposition = @{@"zasset": [NSNull null],
                                         @"conv_id": conversation.identifier,
                                         @"md5": MD5String,
                                         @"width": @1,
                                         @"height": @1,
                                         @"original_width": @(originalSize.width),
                                         @"original_height": @(originalSize.height),
                                         @"inline": @(isInline),
                                         @"public": @NO,
                                         @"correlation_id": correlationIdentifier.transportString,
                                         @"tag": @"preview",
                                         @"nonce": correlationIdentifier.transportString,
                                         @"native_push": @NO,
                                         };
    ZMTransportResponse *response = [self responseForImageData:data contentDisposition:disposition path:path];
    
    // then
    [self.sut.managedObjectContext performBlockAndWait:^{
        NSMutableOrderedSet *addedEvents = [conversation.events mutableCopy];
        [addedEvents minusOrderedSet:eventsStart];
        XCTAssertEqual(addedEvents.count, 1U);
        MockEvent *previewEvent = addedEvents.firstObject;
        XCTAssertEqualObjects(previewEvent.from, self.sut.selfUser);
        XCTAssertNotNil([ZMEventID eventIDWithString:previewEvent.identifier], @"%@", previewEvent.identifier);
        XCTAssertEqualObjects(previewEvent.type, @"conversation.asset-add");
        XCTAssertEqual(previewEvent.conversation, conversation);
        if (isInline) {
            NSData *recievedData = [[NSData alloc] initWithBase64EncodedString:previewEvent.data[@"data"] options:0];
            AssertEqualData(recievedData, data);
        }
        else {
            XCTAssertEqualObjects(previewEvent.data[@"data"], [NSNull null]);
        }
        AssertDateIsRecent(previewEvent.time);
    }];
    
    XCTAssertNotNil(response);
    NSDictionary *responseDictionary = [response.payload asDictionary];
    NSUUID *assetID = [[responseDictionary dictionaryForKey:@"data"] uuidForKey:@"id"];
    XCTAssertNotNil(assetID);

    return response;
}

- (void)testThatItInsertsAnEventsWhenPostingPreviewImageToAConversationV1;
{
    // given
    __block MockConversation *conversation;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
    }];
    WaitForAllGroupsToBeEmpty(0.5);

    // then
    [self checkThatItInsertsAnEventsWhenPostingPreviewImageToAConversation:conversation
                                                                      path:@"/assets"
                                                                      data:[self verySmallJPEGData]
                                                                  isInline:YES];
}


- (void)testThatItInsertsAnEventsWhenPostingPreviewImageToAConversationV2;
{
    // given
    __block MockConversation *conversation;
    __block NSString *conversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
        conversationID = conversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);

    // then
    NSString *path = [NSString pathWithComponents:@[@"/",@"conversations", conversation.identifier, @"assets"]];
    [self checkThatItInsertsAnEventsWhenPostingPreviewImageToAConversation:conversation
                                                                      path:path
                                                                      data:[self verySmallJPEGData]
                                                                  isInline:YES];
}

- (void)testThatItInsertsAnEventsWhenPostingMediumImageToAConversationV1;
{
    // given
    __block MockConversation *conversation;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    [self checkThatItInsertsAnEventsWhenPostingPreviewImageToAConversation:conversation
                                                                      path:@"/assets"
                                                                      data:[self verySmallJPEGData]
                                                                  isInline:NO];
}

- (void)testThatItInsertsAnEventsWhenPostingMediumImageToAConversationV2;
{
    // given
    __block MockConversation *conversation;
    __block NSString *conversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
        conversationID = conversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    NSString *path = [NSString pathWithComponents:@[@"/",@"conversations", conversation.identifier, @"assets"]];
    [self checkThatItInsertsAnEventsWhenPostingPreviewImageToAConversation:conversation
                                                                      path:path
                                                                      data:[self verySmallJPEGData]
                                                                  isInline:NO];
}

- (void)checkThatItCanGetMediumImageAtPath:(NSString *)path expectedData:(NSData *)expectedData
{
    ZMTransportResponse *getResponse = [self responseForPayload:nil path:path method:ZMMethodGET];
    
    // then
    XCTAssertNotNil(getResponse);
    XCTAssertEqual(getResponse.HTTPStatus, 200);
    XCTAssertEqual(getResponse.result, ZMTransportResponseStatusSuccess);
    AssertEqualData(getResponse.imageData, expectedData);
    XCTAssertNil(getResponse.payload);
}

- (void)testThatItReturnsMediumImageDataAfterItHasBeenUploadedV1
{
    // given
    __block MockConversation *conversation;
    __block NSString *conversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
        conversationID = conversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSData *mediumData = [self verySmallJPEGData];
    
    // when
    ZMTransportResponse *postResponse = [self checkThatItInsertsAnEventsWhenPostingPreviewImageToAConversation:conversation
                                                                                                          path:@"/assets"
                                                                                                          data:mediumData
                                                                                                      isInline:NO];
    
    NSUUID *assetID = [[[postResponse.payload asDictionary] dictionaryForKey:@"data"] uuidForKey:@"id"];

    NSString *query = [NSString stringWithFormat:@"%@?conv_id=%@", assetID.transportString, conversationID];
    NSString *getPath = [NSString pathWithComponents:@[@"/assets", query]];
    
    // then
    [self checkThatItCanGetMediumImageAtPath:getPath expectedData:mediumData];
}

- (void)testThatItReturnsMediumImageDataAfterItHasBeenUploadedV2
{
    // given
    __block MockConversation *conversation;
    __block NSString *conversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
        conversationID = conversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSData *mediumData = [self verySmallJPEGData];
    NSString *path = [NSString pathWithComponents:@[@"/",@"conversations", conversation.identifier, @"assets"]];

    // when
    ZMTransportResponse *postResponse = [self checkThatItInsertsAnEventsWhenPostingPreviewImageToAConversation:conversation
                                                                                                          path:path
                                                                                                          data:mediumData
                                                                                                      isInline:NO];
    
    NSUUID *assetID = [[[postResponse.payload asDictionary] dictionaryForKey:@"data"] uuidForKey:@"id"];
    NSString *getPath = [NSString pathWithComponents:@[@"/", @"conversations", conversation.identifier, @"assets", assetID.transportString]];
    
    // then
    [self checkThatItCanGetMediumImageAtPath:getPath expectedData:mediumData];
}

- (void)testThatWeCanSetAConversationNameUsingPUT
{
    // given
    NSString *conversationName = @"New name";
    __block MockConversation *conversation;
    __block NSString *conversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
        [conversation changeNameByUser:session.selfUser name:@"Boring old name"];
        conversationID = conversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSDictionary *payload = @{ @"name": conversationName };
    
    NSString *path = [@"/conversations/" stringByAppendingString:conversationID];
    
    // when
    ZMTransportResponse *response = [self responseForPayload:payload path:path method:ZMMethodPUT];
    
    // then
    [self.sut.managedObjectContext performBlockAndWait:^{
        XCTAssertEqualObjects(conversation.name, conversationName);
        XCTAssertNotNil(response);
        XCTAssertEqual(response.HTTPStatus, 200);
    }];
}


- (void)testThatWeCanDeleteAParticipantFromAConversation
{
    // given
    __block MockUser *selfUser;
    __block MockUser *user1;
    __block MockUser *user2;
    
    __block MockConversation *groupConversation;
    __block NSString *groupConversationID;
    __block NSString *user1ID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        user1 = [session insertUserWithName:@"Foo"];
        user1ID = user1.identifier;
        user2 = [session insertUserWithName:@"Bar"];
        
        groupConversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1, user2]];
        groupConversation.creator = user2;
        groupConversationID = groupConversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSString *path = [NSString pathWithComponents:@[@"/", @"conversations", groupConversationID, @"members", user1ID]];
    
    ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodDELETE];
    
    // then
    XCTAssertNotNil(response);
    if (!response) {
        return;
    }
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertNil(response.transportSessionError);
    
    [self.sut.managedObjectContext performBlockAndWait:^{
        XCTAssertEqualObjects(groupConversation.activeUsers.set, ([NSSet setWithObjects:selfUser, user2, nil]) );
        XCTAssertEqualObjects(groupConversation.inactiveUsers, ([NSSet setWithObject:user1]) );
    }];
}


- (void)testThatWeCanAddParticipantsToAConversation
{
    // given
    __block MockUser *selfUser;
    __block MockUser *user1;
    __block MockUser *user2;
    __block MockUser *user3;
    
    __block MockConversation *groupConversation;
    __block NSString *groupConversationID;
    __block NSString *user3ID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        user1 = [session insertUserWithName:@"Foo"];
        user2 = [session insertUserWithName:@"Bar"];
        user3 = [session insertUserWithName:@"H.P. Baxxter"];
        user3ID = user3.identifier;
        
        MockConnection *connection1 = [session insertConnectionWithSelfUser:selfUser toUser:user3];
        connection1.status = @"accepted";
        connection1.lastUpdate = [NSDate dateWithTimeIntervalSince1970:1399920861.091];
        
        groupConversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1, user2]];
        groupConversation.creator = user2;
        groupConversationID = groupConversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSString *path = [NSString pathWithComponents:@[@"/", @"conversations", groupConversationID, @"members"]];
    NSDictionary *payload = @{
                              @"users": @[user3ID.lowercaseString]
                              };
    
    ZMTransportResponse *response = [self responseForPayload:payload path:path method:ZMMethodPOST];
    
    // then
    XCTAssertNotNil(response);
    if (!response) {
        return;
    }
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertNil(response.transportSessionError);
    
    [self.sut.managedObjectContext performGroupedBlock:^{
        NSOrderedSet *activeUsers = groupConversation.activeUsers;
        XCTAssertEqualObjects(activeUsers, ([NSOrderedSet orderedSetWithObjects:selfUser, user1, user2, user3, nil]) );
        XCTAssertEqualObjects(groupConversation.inactiveUsers, [NSSet set] );
    }];
}

- (void)testThatItRefusesToAddMembersToTheConversationThatAreNotConnectedToTheSelfUser
{
    // given
    __block MockUser *selfUser;
    __block MockUser *user1;
    __block MockUser *user2;
    __block MockUser *user3;
    
    __block MockConversation *groupConversation;
    __block NSString *groupConversationID;
    __block NSString *user3ID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        user1 = [session insertUserWithName:@"Foo"];
        user2 = [session insertUserWithName:@"Bar"];
        user3 = [session insertUserWithName:@"H.P. Baxxter"];
        user3ID = user3.identifier;
        
        groupConversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1, user2]];
        groupConversation.creator = user2;
        groupConversationID = groupConversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSString *path = [NSString pathWithComponents:@[@"/", @"conversations", groupConversationID, @"members"]];
    NSDictionary *payload = @{
                              @"users": @[user3ID.lowercaseString]
                              };
    
    ZMTransportResponse *response = [self responseForPayload:payload path:path method:ZMMethodPOST];
    
    // then
    XCTAssertNotNil(response);
    if (!response) {
        return;
    }
    XCTAssertEqual(response.HTTPStatus, 403);
    XCTAssertNil(response.transportSessionError);
    [self.sut.managedObjectContext performBlockAndWait:^{
        XCTAssertEqualObjects(groupConversation.activeUsers.set, ([NSSet setWithObjects:selfUser, user1, user2, nil]) );
        XCTAssertEqualObjects(groupConversation.inactiveUsers, [NSSet set] );
    }];
}


- (void)testThatWeCanInsertKnockMessagesInAConversation
{
    NSUUID *nonce = [NSUUID createUUID];
    NSDictionary *expectedPayload = @{@"nonce":nonce.transportString};
    
    [self checkThatWeCanAddKnockWithExpectedPayload:expectedPayload block:^MockEvent *(MockConversation *conversation, MockUser *selfUser) {
        return [conversation insertKnockFromUser:selfUser nonce:nonce];
    }];
}


- (void)testThatWeCanInsertHotKnockMessagesInAConversation
{
    NSUUID *nonce = [NSUUID createUUID];
    NSString *oldKnockRef = [self createEventID].transportString;
    
    NSDictionary *expectedPayload = @{@"nonce":nonce.transportString, @"ref": oldKnockRef };
    
    [self checkThatWeCanAddKnockWithExpectedPayload:expectedPayload block:^MockEvent *(MockConversation *conversation, MockUser *selfUser) {
        return [conversation insertHotKnockFromUser:selfUser nonce:nonce ref:oldKnockRef];
        
    }];
}


- (void)checkThatWeCanAddKnockWithExpectedPayload:(NSDictionary *)expectedPayload block:(MockEvent *(^)(MockConversation *, MockUser *))block {
    // given
    __block MockUser *selfUser;
    
    __block MockConversation *conversation;
    __block MockEvent *event;
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        MockUser *otherUser = [session insertUserWithName:@"other"];
        
        conversation = [session insertOneOnOneConversationWithSelfUser:selfUser otherUser:otherUser];
        
        // when
        event = block(conversation, selfUser);
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    
    // then
    [self.sut.managedObjectContext performBlockAndWait:^{
        XCTAssertNotNil(event);
        XCTAssertNotNil(event.identifier);
        XCTAssertEqualObjects(event.from, selfUser);
        XCTAssertEqualObjects(event.conversation, conversation);
        XCTAssertEqualObjects(conversation.lastEvent, event.identifier);
        XCTAssertEqualObjects(conversation.lastEventTime, event.time);
        XCTAssertEqualObjects(event.data, expectedPayload);
    }];
    
}


- (void)testThatItAddsAKnockMessage
{
    // given
    __block MockUser *selfUser;
    __block MockUser *user1;
    
    __block MockConversation *oneOnOneConversation;
    __block NSString *selfUserID;
    __block NSString *oneOnOneConversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        selfUser.identifier = [[NSUUID createUUID] transportString];
        selfUserID = selfUser.identifier;
        user1 = [session insertUserWithName:@"Foo"];
        
        oneOnOneConversation = [session insertOneOnOneConversationWithSelfUser:selfUser otherUser:user1];
        oneOnOneConversationID = oneOnOneConversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSUUID *nonce = [NSUUID createUUID];
    NSDictionary *messageRoundtripPayload;
    // (1)
    {
        // when
        NSDictionary *payload = @{
                                  @"nonce" : nonce.transportString
                                  };
        
        NSString *path = [NSString pathWithComponents:@[@"/", @"conversations", oneOnOneConversationID, @"knock"]];
        
        ZMTransportResponse *response = [self responseForPayload:payload path:path method:ZMMethodPOST];
        
        // then
        XCTAssertNotNil(response);
        if (!response) {
            return;
        }
        XCTAssertEqual(response.HTTPStatus, 201);
        XCTAssertNil(response.transportSessionError);
        
        XCTAssertTrue([response.payload isKindOfClass:[NSDictionary class]]);
        NSDictionary *responsePayload = [response.payload asDictionary];
        
        messageRoundtripPayload = responsePayload;
        XCTAssertEqualObjects(responsePayload[@"conversation"], oneOnOneConversationID);
        XCTAssertEqualObjects(responsePayload[@"from"], selfUserID);
        XCTAssertEqualObjects(responsePayload[@"type"], @"conversation.knock");
        XCTAssertNotNil([responsePayload dateForKey:@"time"]);
        AssertDateIsRecent([responsePayload dateForKey:@"time"]);
        XCTAssertNotNil([responsePayload eventForKey:@"id"]);
        
        NSDictionary *data = [responsePayload dictionaryForKey:@"data"];
        XCTAssertNotNil(data);
        XCTAssertEqualObjects([data uuidForKey:@"nonce"], nonce);
    }
    
    // (2)
    {
        // when
        NSString *path = [NSString pathWithComponents:@[@"/", @"conversations", oneOnOneConversationID, @"events?start=1.0&size=300"]];
        ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
        
        // then
        XCTAssertNotNil(response);
        if (!response) {
            return;
        }
        XCTAssertEqual(response.HTTPStatus, 200);
        XCTAssertNil(response.transportSessionError);
        NSArray *events = [[response.payload asDictionary] arrayForKey:@"events"];
        XCTAssertNotNil(events);
        XCTAssertGreaterThanOrEqual(events.count, 1u);
        XCTAssertEqualObjects(events.lastObject, messageRoundtripPayload);
    }
}




- (void)testThatItAddsAHotKnockMessage
{
    // given
    __block MockUser *selfUser;
    __block MockUser *user1;
    
    __block MockConversation *oneOnOneConversation;
    __block NSString *selfUserID;
    __block NSString *oneOnOneConversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        selfUser.identifier = [[NSUUID createUUID] transportString];
        selfUserID = selfUser.identifier;
        user1 = [session insertUserWithName:@"Foo"];
        
        oneOnOneConversation = [session insertOneOnOneConversationWithSelfUser:selfUser otherUser:user1];
        oneOnOneConversationID = oneOnOneConversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSUUID *nonce = [NSUUID createUUID];
    NSDictionary *messageRoundtripPayload;
    // (1)
    {
        // when
        NSDictionary *payload = @{
                                  @"nonce" : nonce.transportString
                                  };
        
        NSString *path = [NSString pathWithComponents:@[@"/", @"conversations", oneOnOneConversationID, @"hot-knock"]];
        
        ZMTransportResponse *response = [self responseForPayload:payload path:path method:ZMMethodPOST];
        
        // then
        XCTAssertNotNil(response);
        if (!response) {
            return;
        }
        XCTAssertEqual(response.HTTPStatus, 201);
        XCTAssertNil(response.transportSessionError);
        
        XCTAssertTrue([response.payload isKindOfClass:[NSDictionary class]]);
        NSDictionary *responsePayload = [response.payload asDictionary];
        
        messageRoundtripPayload = responsePayload;
        XCTAssertEqualObjects(responsePayload[@"conversation"], oneOnOneConversationID);
        XCTAssertEqualObjects(responsePayload[@"from"], selfUserID);
        XCTAssertEqualObjects(responsePayload[@"type"], @"conversation.hot-knock");
        XCTAssertNotNil([responsePayload dateForKey:@"time"]);
        AssertDateIsRecent([responsePayload dateForKey:@"time"]);
        XCTAssertNotNil([responsePayload eventForKey:@"id"]);
        
        NSDictionary *data = [responsePayload dictionaryForKey:@"data"];
        XCTAssertNotNil(data);
        XCTAssertEqualObjects([data uuidForKey:@"nonce"], nonce);
    }
    
    // (2)
    {
        // when
        NSString *path = [NSString pathWithComponents:@[@"/", @"conversations", oneOnOneConversationID, @"events?start=1.0&size=300"]];
        ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
        
        // then
        XCTAssertNotNil(response);
        if (!response) {
            return;
        }
        XCTAssertEqual(response.HTTPStatus, 200);
        XCTAssertNil(response.transportSessionError);
        NSArray *events = [[response.payload asDictionary] arrayForKey:@"events"];
        XCTAssertNotNil(events);
        XCTAssertGreaterThanOrEqual(events.count, 1u);
        XCTAssertEqualObjects(events.lastObject, messageRoundtripPayload);
    }
}


- (void)testThatItReturnsAllConversationIDs
{
    // given
    __block MockUser *selfUser;
    
    NSMutableArray *conversationIDs = [NSMutableArray array];
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        selfUser.identifier = [[NSUUID createUUID] transportString];
        MockUser *user1 = [session insertUserWithName:@"Foo"];
        MockUser *user2 = [session insertUserWithName:@"Bar"];
        
        for (int i=0; i < 278; ++i ) {
            MockConversation *groupConversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1, user2]];
            [conversationIDs addObject:groupConversation.identifier];
        }
        
    }];
    
    // when
    NSString *path = @"/conversations/ids";
    ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
    
    // then
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertNil(response.transportSessionError);
    
    NSArray *receivedTransportIDs = response.payload[@"conversations"];
    XCTAssertEqualObjects([NSSet setWithArray:receivedTransportIDs], [NSSet setWithArray:conversationIDs]);
    
}




- (void)testThatItReturnsConversationsForSpecificIDs
{
    // given
    __block MockUser *selfUser;
    
    NSMutableDictionary *conversationMap = [NSMutableDictionary dictionary];
    
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        selfUser.identifier = [[NSUUID createUUID] transportString];
        MockUser *user1 = [session insertUserWithName:@"Foo"];
        MockUser *user2 = [session insertUserWithName:@"Bar"];
        
        for (int i = 0; i < 78; ++i) {
            MockConversation *groupConversation = [session insertGroupConversationWithSelfUser:selfUser otherUsers:@[user1, user2]];
            conversationMap[groupConversation.identifier] = groupConversation;
        }
    }];
    
    NSMutableSet *randomlyPickedConversations = [NSMutableSet set];
    for (int i = 0; i < 14; ++i) {
        NSUInteger randomIndex = arc4random() % (conversationMap.allValues.count - 1);
        [randomlyPickedConversations addObject: conversationMap.allValues[randomIndex]];
    }
    
    NSArray *requestedConversationIDs = [randomlyPickedConversations.allObjects mapWithBlock:^id(MockConversation *obj) {
        return obj.identifier;
    }];
    
    // when
    NSString *path = [NSString stringWithFormat:@"/conversations?ids=%@", [requestedConversationIDs componentsJoinedByString:@","]];
    ZMTransportResponse *response = [self responseForPayload:nil path:path method:ZMMethodGET];
    
    // then
    XCTAssertEqual(response.HTTPStatus, 200);
    XCTAssertNil(response.transportSessionError);
    
    NSArray *receivedConversations = response.payload[@"conversations"];
    NSMutableSet *receivedConversationIDs = [NSMutableSet set];
    
    for (NSDictionary *rawConversation in receivedConversations) {
        NSString *conversationID = rawConversation[@"id"];
        MockConversation *conversation = conversationMap[conversationID];
        [self checkThatTransportData:rawConversation matchesConversation:conversation];
        [receivedConversationIDs addObject:conversationID];
    }
    
    XCTAssertEqualObjects(receivedConversationIDs, [NSSet setWithArray:requestedConversationIDs]);
}

@end




@implementation MockTransportSessionTests (ConversationArchiveAndMuted)

- (void)testThatItSetsTheArchivedEventOnTheConversationWhenAsked
{
    // given
    __block MockConversation *conversation;
    __block NSString *conversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
        conversationID = conversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    ZMEventID *archivedEvent = [ZMEventID eventIDWithMajor:2 minor:2445];
    
    
    NSDictionary *payload = @{ @"archived":  archivedEvent.transportString };
    
    NSString *path = [NSString stringWithFormat:@"/conversations/%@/self", conversationID];
    
    // when
    ZMTransportResponse *response = [self responseForPayload:payload path:path method:ZMMethodPUT];
    
    // then
    [self.sut.managedObjectContext performBlockAndWait:^{
        XCTAssertNotNil(response);
        XCTAssertEqual(response.HTTPStatus, 200);
        XCTAssertEqualObjects(response.payload, nil);
        XCTAssertEqualObjects(conversation.archived, archivedEvent.transportString);
    }];
    
}

- (void)testThatItUnsetsTheArchivedEventOnTheConversationWhenAsked
{
    // given
    __block MockConversation *conversation;
    __block NSString *conversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
        conversationID = conversation.identifier;
        conversation.archived = @"3.43";
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    
    NSDictionary *payload = @{ @"archived":  @"false" };
    
    NSString *path = [NSString stringWithFormat:@"/conversations/%@/self", conversationID];
    
    // when
    ZMTransportResponse *response = [self responseForPayload:payload path:path method:ZMMethodPUT];
    
    // then
    [self.sut.managedObjectContext performBlockAndWait:^{
        XCTAssertNotNil(response);
        XCTAssertEqual(response.HTTPStatus, 200);
        XCTAssertEqualObjects(response.payload, nil);
        XCTAssertNil(conversation.archived);
    }];
    
}

- (void)testThatItSetsMutedOnTheConversationWhenAsked
{
    // given
    __block MockConversation *conversation;
    __block NSString *conversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
        conversationID = conversation.identifier;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSDictionary *payload = @{ @"muted":  @1 };
    
    NSString *path = [NSString stringWithFormat:@"/conversations/%@/self", conversationID];
    
    // when
    ZMTransportResponse *response = [self responseForPayload:payload path:path method:ZMMethodPUT];
    
    // then
    [self.sut.managedObjectContext performBlockAndWait:^{
        XCTAssertNotNil(response);
        XCTAssertEqual(response.HTTPStatus, 200);
        XCTAssertEqualObjects(response.payload, nil);
        XCTAssertTrue(conversation.muted);
    }];
    
}

- (void)testThatItUnsetsMutedOnTheConversationWhenAsked
{
    // given
    __block MockConversation *conversation;
    __block NSString *conversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [session insertSelfUserWithName:@"Me Myself"];
        conversation = [session insertSelfConversationWithSelfUser:session.selfUser];
        conversationID = conversation.identifier;
        conversation.muted = YES;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSDictionary *payload = @{ @"muted":  @0 };
    
    NSString *path = [NSString stringWithFormat:@"/conversations/%@/self", conversationID];
    
    // when
    ZMTransportResponse *response = [self responseForPayload:payload path:path method:ZMMethodPUT];
    
    // then
    [self.sut.managedObjectContext performBlockAndWait:^{
        XCTAssertNotNil(response);
        XCTAssertEqual(response.HTTPStatus, 200);
        XCTAssertEqualObjects(response.payload, nil);
        XCTAssertFalse(conversation.muted);
    }];
    
}

@end


@implementation  MockTransportSessionTests (IgnoringCall)

- (void)testThatCreatesAnEventForUserIgnoringCall
{
    // given
    __block MockConversation *conversation;
    __block MockUser *selfUser;
    __block NSString *conversationID;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        selfUser = [session insertSelfUserWithName:@"Me Myself"];
        MockUser *otherUser = [session insertUserWithName:@"The other one"];
        conversation = [session insertOneOnOneConversationWithSelfUser:selfUser otherUser:otherUser];
        conversationID = conversation.identifier;
    }];
    
    // when
    NSUInteger events = self.sut.updateEvents.count;
    [self.sut performRemoteChanges:^(MockTransportSession<MockTransportSessionObjectCreation> *session) {
        [conversation ignoreCallByUser:selfUser];
        [session saveAndCreatePushChannelEventForSelfUser];
    }];
    
    // then
    XCTAssertGreaterThan(self.sut.updateEvents.count, events);
    
    
}

@end


