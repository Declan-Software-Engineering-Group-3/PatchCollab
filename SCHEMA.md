# PatchCollab Firestore schema (final, for the build)

Group SE3 | ITMDA3-B34. This applies the section 2 amendments from the Build Kickoff. Where this file and an earlier deliverable disagree, this file is current. Collection names are lowercase plural and field names are camelCase, following the README.

Rules for everyone: `createdAt` is always `FieldValue.serverTimestamp()`. Counters (`voteCount`) are only ever written by Cloud Functions. Notifications are only ever created by Cloud Functions.

## users/{userId}

The document id is the Firebase Auth uid. Written by the owner (Mateus).

| Field | Type | Notes |
|---|---|---|
| userId | string | Same as the document id |
| displayName | string | |
| email | string | |
| profileImageUrl | string, nullable | Firebase Storage URL |
| fcmTokens | array of string | One token per device. Append on login, never overwrite. Stale tokens are removed by the send helper when FCM reports them unregistered |
| createdAt | timestamp | |

## projects/{projectId}

| Field | Type | Notes |
|---|---|---|
| projectId | string | |
| ownerId | string | uid of the creator |
| title | string | |
| description | string | |
| technology | string | Filter field |
| difficulty | string | Filter field |
| category | string | Filter field |
| githubUrl | string, nullable | |
| createdAt | timestamp | |

### projects/{projectId}/members/{userId}

Document id is the member's uid. Added by the approval function, apart from the owner's own row at project creation.

| Field | Type | Notes |
|---|---|---|
| userId | string | |
| role | string | owner or member |
| joinedAt | timestamp | |

### projects/{projectId}/membershipRequests/{requestId}

| Field | Type | Notes |
|---|---|---|
| requestId | string | |
| userId | string | Requester |
| status | string | pending, approved, rejected. Only the approval function changes it |
| createdAt | timestamp | |

## questions/{questionId}

Community questions and code review requests share one collection.

| Field | Type | Notes |
|---|---|---|
| questionId | string | |
| userId | string | Author |
| title | string | |
| content | string | |
| codeSnippet | string, nullable | Null for a general question |
| language | string, nullable | Drives the language-based community spaces |
| category | string | |
| type | string | `question` or `reviewRequest` |
| githubUrl | string, nullable | Repository link for larger codebases |
| voteCount | number | Starts at 0. Cloud Function only |
| acceptedAnswerId | string, nullable | Cloud Function only |
| createdAt | timestamp | |

### questions/{questionId}/votes/{userId}

One document per voter, document id is the voter's uid. This is what prevents double voting. A vote counter function runs on writes here.

| Field | Type | Notes |
|---|---|---|
| userId | string | |
| value | number | 1 or -1 |
| createdAt | timestamp | |

## answers/{answerId}

Answers carry the reviewer and author discussion. There is no separate comments collection.

| Field | Type | Notes |
|---|---|---|
| answerId | string | |
| questionId | string | Parent question |
| userId | string | Author |
| content | string | |
| voteCount | number | Starts at 0. Cloud Function only |
| isAccepted | boolean | Starts false. Cloud Function only |
| createdAt | timestamp | |

### answers/{answerId}/votes/{userId}

Same shape and behaviour as the questions votes subcollection.

## friendships/{friendshipId}

| Field | Type | Notes |
|---|---|---|
| friendshipId | string | |
| userId | string | Who sent the request |
| friendId | string | Who received it |
| participants | array of string | Exactly two uids, used for querying with `arrayContains` |
| status | string | pending or accepted. Rejecting deletes the document |
| createdAt | timestamp | |

## conversations/{conversationId}

Replaces the flat Messages collection. Messaging is not gated behind friendship.

| Field | Type | Notes |
|---|---|---|
| conversationId | string | |
| participants | array of string | Exactly two uids |
| lastMessage | string | |
| lastMessageAt | timestamp | |

### conversations/{conversationId}/messages/{messageId}

| Field | Type | Notes |
|---|---|---|
| messageId | string | |
| senderId | string | |
| text | string | |
| isRead | boolean | Only the recipient can set it |
| createdAt | timestamp | |

## notifications/{notificationId}

Created by Cloud Functions through the shared helper. The recipient can only mark them read or delete them.

| Field | Type | Notes |
|---|---|---|
| notificationId | string | |
| userId | string | Recipient |
| type | string | For example newAnswer, newReviewRequest, friendRequest, joinRequest, newMessage |
| message | string | Display text |
| relatedId | string, nullable | Id of the question, project, conversation and so on |
| isRead | boolean | |
| createdAt | timestamp | |

## aiRequests/{requestId}

Written only by the PatchCollab AI function. The per-student daily cap is counted from this collection, so clients cannot edit or delete their own records.

| Field | Type | Notes |
|---|---|---|
| requestId | string | |
| userId | string | |
| prompt | string | Up to 4000 characters |
| response | string, nullable | Null while the request is in flight |
| type | string | review, summarise or explain |
| createdAt | timestamp | |

## Composite indexes

Declared in `firestore.indexes.json`: answers (`questionId` + `createdAt`, both directions), notifications (`userId` + `createdAt`), questions (`category`, `language` and `type`, each + `createdAt`), aiRequests (`userId` + `createdAt`, both directions), conversations (`participants` + `lastMessageAt`). If a new query throws an index error, click the link in the error, create the index, then add it to `firestore.indexes.json` and commit it.

## Cloud Functions calls

The AI function is a callable in region `africa-south1`, so the client must use `FirebaseFunctions.instanceFor(region: 'africa-south1')`. It takes `prompt` (string) and `type` (review, summarise or explain) and returns `requestId`, `response` and `remaining`. It fails with `resource-exhausted` when the student has used their 20 requests for the day.
