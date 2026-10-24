# PatchCollab

Peer code review is standard practice in professional software development, but undergraduate students rarely get structured exposure to it. The tools that support it, such as GitHub, GitLab and Gerrit, are built for professional teams working at a desktop, which makes them a poor fit for students working from their phones between lectures.

PatchCollab is an Android application that brings structured peer code review into a mobile, student-focused environment. Students create and join projects, post questions and review requests to a shared community feed, exchange constructive feedback on each other's code, and build up a record of the reviews they have given and received. An in-app assistant, PatchCollab AI, can review, summarise and explain a snippet before a human reviewer sees it, so the feedback a student receives starts from a more informed position.

The application is built in Flutter against a Firebase backend, with privileged operations handled by Cloud Functions so that actions such as approving a join request or accepting an answer cannot be performed by the requesting student's own device.

This project accompanies a research study into how tool-assisted peer code review affects software quality and knowledge sharing among junior developers in undergraduate software engineering programmes. The findings from that study informed the feature set and the design decisions recorded in this repository.

Group SE3 | ITMDA3-B34 | Eduvos Bedfordview

---

## Read this first

If you are setting up for the first time, work through sections 1 to 4 **in order**. Do not skip ahead. Section 5 onwards is reference material you will come back to.

If something does not work, check section 10 (Troubleshooting) before asking. Most first-run problems are listed there.

**Rules that matter most:**

1. Never push directly to `main`.
2. Never commit an API key, a `google-services.json`, or anything from `.env`.
3. Follow the Riverpod pattern in section 6. Do not invent your own.
4. If you need to change something outside your own feature folder, ask in the group chat first.

---

## 1. What you need installed

| Tool | Version | Where to get it |
|---|---|---|
| Flutter SDK | **3.47.5** | https://docs.flutter.dev/get-started/install |
| Android Studio | Latest stable | https://developer.android.com/studio |
| VS Code | Latest stable | https://code.visualstudio.com |
| Node.js | 20 LTS or higher | https://nodejs.org |
| Firebase CLI | Latest | `npm install -g firebase-tools` |
| FlutterFire CLI | Latest | `dart pub global activate flutterfire_cli` |
| Git | Any recent version | https://git-scm.com |

We target **Android only**. You do not need a Mac and you do not need Xcode.

### Why both Android Studio and VS Code

**Android Studio is required, but you do not have to write code in it.** Flutter builds Android apps by calling the Android SDK, the platform tools, the build tools and a Java runtime. Those are mandatory and `flutter doctor` fails without them. Android Studio is the reliable way to install all of that in one step, and it is where you create and manage emulators.

**VS Code is the recommended editor.** Install the **Flutter** and **Dart** extensions from the marketplace (search for them in the Extensions panel, publisher is Dart Code for both). It is lighter than Android Studio and it is what most Flutter developers use day to day.

So in practice: install Android Studio, use it for the emulator and nothing else, and write your code in VS Code. If you would rather write code in Android Studio as well, that is fine, the editor is a free choice. Everything else in this README is not.

### Pinning the Flutter version

Everyone runs Flutter **3.47.5**. Check yours:

```bash
flutter --version
```

If it does not match, switch to it:

```bash
cd <your flutter sdk folder>
git checkout 3.47.5
flutter doctor
```

Confirm the version has actually changed by running `flutter --version` again before you carry on.

Version drift is the single most common cause of "it works on my machine". Do not upgrade Flutter mid-project without telling the group.

### Confirm your setup is healthy

```bash
flutter doctor
```

You need green ticks for **Flutter**, **Android toolchain**, and **Android Studio**. Anything about Xcode, CocoaPods or iOS can be ignored. If the Android licence check fails:

```bash
flutter doctor --android-licenses
```

Accept all of them.

---

## 2. Getting the code

```bash
git clone https://github.com/Declan-Software-Engineering-Group-3/PatchCollab.git
cd PatchCollab
```

### Set your Git identity

So we can tell who wrote what:

```bash
git config user.name "Your Full Name"
git config user.email "your.student.email@eduvos.com"
```

---

## 3. Firebase setup

Arav will have added you to the Firebase project. You need to be able to log in and pull the config down.

```bash
firebase login
```

Use the Google account Arav added. Then from the `app/` folder:

```bash
cd app
flutterfire configure --project=patchcollab
```

When prompted for platforms, select **Android only**. This generates `lib/firebase_options.dart` and `android/app/google-services.json`.

> **Both of these files are gitignored on purpose. Never commit them.** If you see either in `git status`, stop and tell the group. They contain project configuration that should not sit in a public repo.

---

## 4. First run

```bash
cd app
flutter pub get
flutter run
```

Pick an emulator or a connected device when prompted.

In VS Code you can also press **F5** to run with the debugger attached, which gives you breakpoints and hot reload. The device selector sits in the bottom right of the status bar.

### Setting up an emulator

In Android Studio: **Tools > Device Manager > Create Device**. Pick a Pixel 6 or similar, choose a recent system image, finish, and press play.

### Using your own phone

Enable Developer Options (tap Build Number seven times in Settings > About Phone), turn on USB Debugging, plug it in, and accept the prompt on the phone.

**You are done with setup when the app builds and you reach the login screen.** Tell the group chat when you get there.

### Cloud Functions

The client calls Cloud Functions for anything privileged, so you need them installed before those features work:

```bash
cd functions
npm install
```

To run them locally against the emulator suite rather than the deployed functions:

```bash
firebase emulators:start --only functions,firestore
```

**Only Arav deploys to production.** If your feature needs a function deployed, ask rather than running `firebase deploy` yourself.

---

## 5. Project structure

```
PatchCollab/
├── app/                          Flutter client
│   ├── lib/
│   │   ├── main.dart
│   │   ├── firebase_options.dart      (generated, gitignored)
│   │   ├── core/                      shared across all features
│   │   │   ├── models/                Question, Answer, Project, AppUser...
│   │   │   ├── providers/             shared providers (auth state, current user)
│   │   │   ├── theme/                 colours, text styles
│   │   │   ├── widgets/               shared widgets (loading, error, empty states)
│   │   │   └── utils/
│   │   └── features/
│   │       ├── auth/                  Mateus
│   │       ├── profile/               Mateus
│   │       ├── projects/              Aidan
│   │       ├── community/             Declan
│   │       ├── ai/                    Declan
│   │       ├── github/                Aidan  (repository linking)
│   │       └── social/                Deylan  (friends, messages, notifications)
│   └── pubspec.yaml
├── functions/                    Cloud Functions
│   ├── src/
│   │   ├── auth/
│   │   ├── projects/
│   │   ├── community/
│   │   ├── social/
│   │   ├── github/
│   │   └── ai/
│   └── package.json
├── firestore.rules
├── firestore.indexes.json
├── SCHEMA.md
└── README.md
```

### Inside a feature folder

Every feature folder follows the same shape. Copy it exactly:

```
features/community/
├── data/              Firestore queries and writes for this feature
├── providers/         Riverpod providers and notifiers
├── screens/           full pages
└── widgets/           pieces used only by this feature
```

### Who owns what

| Person | Folders they own |
|---|---|
| Arav | `firestore.rules`, `firestore.indexes.json`, `functions/` setup, `functions/src/ai/` |
| Mateus | `features/auth/`, `features/profile/` |
| Aidan | `features/projects/`, `features/github/`, `functions/src/projects/`, `functions/src/github/` |
| Declan | `features/community/`, `features/ai/`, `functions/src/community/` |
| Deylan | `features/social/`, `functions/src/social/` |

**`core/` is shared.** If you need to add something there, say so in the group chat first. Two people adding a different `LoadingIndicator` on the same day is a waste of everyone's time.

---

## 6. How we write state management (Riverpod)

Riverpod allows several ways of doing the same thing. We use one. Read this section properly, it will save you rewriting your feature later.

### The rules

1. **One `StreamProvider` per Firestore query.** Reading data from Firestore is always a `StreamProvider`.
2. **One `Notifier` per feature** for anything with logic (submitting, validating, multi-step actions).
3. **Never declare a provider inside a widget file.** Providers live in `providers/`.
4. **No Riverpod code generation.** No `@riverpod` annotations, no `build_runner`. It adds a build step we do not need.
5. **`ref.watch` in `build()`, `ref.read` in callbacks.** Getting this backwards is the most common Riverpod bug. See below.

### watch vs read

- `ref.watch(...)` — use inside `build()`. The widget rebuilds when the value changes.
- `ref.read(...)` — use inside `onPressed`, `onTap`, or any callback. Reads once, no subscription.

Using `watch` inside a callback causes rebuild loops. Using `read` inside `build()` means your UI silently stops updating. If your screen is not refreshing, check this first.

### Worked example: reading a list from Firestore

**The model** — `core/models/question.dart`

```dart
class Question {
  final String questionId;
  final String userId;
  final String title;
  final String content;
  final String? codeSnippet;
  final String? language;
  final String category;
  final String type;          // 'question' or 'reviewRequest'
  final int voteCount;
  final DateTime createdAt;

  Question({
    required this.questionId,
    required this.userId,
    required this.title,
    required this.content,
    this.codeSnippet,
    this.language,
    required this.category,
    required this.type,
    required this.voteCount,
    required this.createdAt,
  });

  factory Question.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Question(
      questionId: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      content: data['content'] as String,
      codeSnippet: data['codeSnippet'] as String?,
      language: data['language'] as String?,
      category: data['category'] as String,
      type: data['type'] as String,
      voteCount: (data['voteCount'] ?? 0) as int,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'title': title,
    'content': content,
    'codeSnippet': codeSnippet,
    'language': language,
    'category': category,
    'type': type,
    'voteCount': voteCount,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
```

**The provider** — `features/community/providers/questions_provider.dart`

```dart
final questionsProvider = StreamProvider<List<Question>>((ref) {
  return FirebaseFirestore.instance
      .collection('questions')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Question.fromDoc).toList());
});
```

**The screen** — `features/community/screens/community_screen.dart`

```dart
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(questionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: questions.when(
        data: (list) {
          if (list.isEmpty) return const EmptyState(message: 'No questions yet');
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => QuestionTile(question: list[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e),
      ),
    );
  }
}
```

That is the whole pattern. `ConsumerWidget` instead of `StatelessWidget`, `ref.watch` in build, `.when()` to handle loading and error. Every list screen in the app looks like this.

### Worked example: writing with a Notifier

For anything that submits or changes data:

```dart
// features/community/providers/post_question_notifier.dart

class PostQuestionNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> post({
    required String title,
    required String content,
    String? codeSnippet,
    String? language,
    required String category,
    required String type,
  }) async {
    state = const AsyncLoading();
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('questions').add({
        'userId': uid,
        'title': title,
        'content': content,
        'codeSnippet': codeSnippet,
        'language': language,
        'category': category,
        'type': type,
        'voteCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final postQuestionProvider =
    NotifierProvider<PostQuestionNotifier, AsyncValue<void>>(
        PostQuestionNotifier.new);
```

Called from a button:

```dart
onPressed: () {
  ref.read(postQuestionProvider.notifier).post(
    title: titleController.text,
    content: contentController.text,
    category: selectedCategory,
    type: 'question',
  );
},
```

Note `ref.read` here, because it is a callback.

---

## 7. Working with Firestore

### SCHEMA.md is the authority

`SCHEMA.md` at the repo root holds the final collection and field definitions. Build your models against it, not against an earlier deliverable. Where the two disagree, SCHEMA.md is current.

Three field names changed from the earlier deliverables, so check yours:

| Earlier docs | Now |
|---|---|
| `fullName` | `displayName` |
| `profileImage` | `profileImageUrl` |
| `githubRepository` | `githubUrl` |

If you need a new field or collection, raise it in the group chat rather than adding it quietly. Someone else is probably reading the same document.

### Always use serverTimestamp for createdAt

```dart
'createdAt': FieldValue.serverTimestamp(),
```

Never `DateTime.now()`. A student's phone clock can be wrong, and then their post sorts to the wrong place in the list.

### Never write a counter from the app

`voteCount` and any other counter is updated by a Cloud Function using a transaction. If two students vote at the same moment and both write from the client, one increment is lost. This is not theoretical, it happens immediately in testing.

### Anything sensitive goes through a Cloud Function

Call a Cloud Function, not a direct Firestore write, when the action:

- touches an external service (GitHub, Gemini)
- must be validated server-side (approving a join request, accepting an answer)
- updates a counter
- triggers a notification

A student's own phone must never be able to approve its own join request or mark its own answer as accepted.

### Composite indexes

These are already declared in `firestore.indexes.json` and deployed:

- `answers`: `questionId` + `createdAt`, both directions
- `notifications`: `userId` + `createdAt`
- `questions`: `category` + `createdAt`, `language` + `createdAt`, `type` + `createdAt`
- `aiRequests`: `userId` + `createdAt`, both directions
- `conversations`: `participants` (array contains) + `lastMessageAt`

If you write a query that needs a new one, Firestore throws an error in the console **with a direct link to create it**. Click the link, create the index, then add it to `firestore.indexes.json` and commit it so everyone else gets it too.

---

## 8. Git workflow

### Branches

`main` is protected. You work on your feature branch.

| Person | Branch |
|---|---|
| Mateus | `feature/auth` |
| Aidan | `feature/projects` |
| Declan | `feature/community` |
| Deylan | `feature/social` |
| Arav | `feature/infra` |

Short-lived branches for a single piece of work are fine too, named `area/what-it-does`, for example `docs/readme` or `community/review-diff`.

### Daily routine

Start of a session, pull the latest main into your branch:

```bash
git checkout main
git pull
git checkout feature/<yours>
git merge main
```

Doing this daily means small conflicts instead of one enormous one at the end.

### Committing

```bash
git add .
git commit -m "community: add question list screen"
git push
```

Commit message format is `area: what you did`, lowercase, present tense. Areas: `auth`, `profile`, `projects`, `community`, `ai`, `github`, `social`, `infra`, `docs`.

Commit often. A commit per working piece is better than one per day.

### Pull requests

When your feature works:

1. Push your branch.
2. Open a pull request into `main` on GitHub.
3. In the description, say what it does and what to test.
4. Tag one teammate for review.
5. They review, comment, approve.
6. Merge.

**Nothing reaches `main` without one other person approving it.** This is not bureaucracy, it is the practice our research is about, and we will be writing about having done it.

### Reviewing someone's PR

Spend ten minutes. Look for:

- Does it follow the Riverpod pattern in section 6?
- Any hardcoded keys, secrets or test data left in?
- Any `print()` statements left behind?
- Does it touch files outside their feature folder without saying so?

Leave a comment even when approving. A review that just says "approved" is not a review.

---

## 9. Naming and conventions

| Thing | Convention | Example |
|---|---|---|
| Files | `snake_case.dart` | `question_tile.dart` |
| Classes | `PascalCase` | `QuestionTile` |
| Variables and functions | `camelCase` | `voteCount` |
| Providers | end in `Provider` | `questionsProvider` |
| Firestore collections | lowercase plural | `questions`, `answers` |
| Firestore fields | `camelCase` | `createdAt`, `acceptedAnswerId` |

Run the formatter before committing:

```bash
dart format lib/
flutter analyze
```

`flutter analyze` must be clean before you open a PR.

### The assistant is called PatchCollab AI

Not DevLink AI. If you see DevLink anywhere, it is a leftover from an earlier draft. Fix it.

---

## 10. Troubleshooting

### Setup stage

**`flutter doctor` warns "Currently on an unknown channel"**

Expected. Ignore it. This appears because we are checked out to a specific version tag rather than tracking a branch, which is exactly what pinning means.

**Do not run `flutter channel` even though the warning tells you to.** That moves you off 3.47.5 and undoes the pin, and you will end up on a different version to everyone else.

**`flutter doctor` shows red for Xcode and CocoaPods**

Expected and permanent. Those are for iOS and macOS builds. We target Android only, so they will never go green and it does not matter.

The lines that must be green are **Flutter**, **Android toolchain** and **Connected device**. Everything else is noise.

**`git clone` of Flutter fails with "destination path 'flutter' already exists"**

You already have a Flutter checkout there, probably from a previous attempt. Check whether it is usable:

```bash
cd ~/development/flutter
git log -1
```

If that prints a commit, the clone is fine. Skip to the `git checkout 3.47.5` step. If it errors saying it is not a git repository, delete the folder and clone again.

**`flutterfire` or `firebase` command not found**

The PATH line has not taken effect in your current terminal. Run `source ~/.zshrc`, or just open a new terminal tab.

**`flutterfire configure` says the Android app "is not registered" and then registers one**

That is correct behaviour, not an error. It found the existing `patchcollab` project and created the Android app registration inside it. Your Firestore, Authentication, Storage and Messaging settings are untouched.

### Build and run stage

**`flutter run` fails with a Gradle error**

```bash
cd app
flutter clean
flutter pub get
flutter run
```

Solves most of these. The first build after a clean is slow, give it a few minutes.

**`firebase_options.dart` not found**

You skipped section 3. Run `flutterfire configure` again.

**"No Firebase App '[DEFAULT]' has been created"**

Firebase is not initialised before it is used. `main()` needs:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: PatchCollabApp()));
}
```

Note `ProviderScope`. Riverpod does nothing without it.

**My screen does not update when data changes**

You used `ref.read` where you needed `ref.watch`. See section 6.

**The app rebuilds endlessly**

You used `ref.watch` inside a callback. See section 6.

**"The query requires an index"**

Click the link in the error. Create the index. Add it to `firestore.indexes.json` and commit.

**A Cloud Function call fails with "not found" or "internal"**

The function is either not deployed or you have not run `npm install` in `functions/`. See section 4. If it is deployed and still failing, check the function logs in the Firebase console before guessing.

**Notifications work on one device but not another**

`fcmTokens` is an array for this reason. If you overwrote it instead of appending, your other device's token is gone.

**Permission denied writing to Firestore**

The security rules are blocking you. Either you are not signed in, or the rule for that collection is not written yet. Ask Arav rather than loosening the rules yourself.

**Something is broken and none of this helps**

Post in the group chat with: what you ran, the full error text, and what you already tried. A screenshot of half the error is not enough to help with.

---

## 11. Security

Never commit:

- `google-services.json`
- `firebase_options.dart`
- `.env` or any file with a key in it
- Gemini API keys
- GitHub tokens

All keys live in Cloud Functions environment configuration, set by Arav. They never appear in the Flutter app.

If you commit a secret by accident, tell the group immediately. Removing it in a later commit does not remove it from the history, and the key has to be rotated.

---

## 12. Definition of done

A feature is done when:

- It works on a physical Android device, not only the emulator
- Loading, empty and error states are all handled
- `flutter analyze` is clean
- There are no `print()` statements or commented-out blocks left
- It follows the Riverpod pattern in section 6
- A teammate has reviewed and approved the PR

---

## 13. Who to ask

| Topic | Person |
|---|---|
| Firestore schema, security rules, indexes, Cloud Functions setup | Arav |
| Login, registration, profile | Mateus |
| Projects, membership, GitHub linking | Aidan |
| Community, questions, answers, PatchCollab AI | Declan |
| Friends, messaging, notifications | Deylan |
| Anything in `core/`, or a decision that affects everyone | Group chat |