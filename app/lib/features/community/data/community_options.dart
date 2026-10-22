// schema has no fixed list for these, change if the team agrees on one
const questionLanguages = [
  'Java',
  'Python',
  'JavaScript',
  'Dart',
  'Kotlin',
  'C#',
  'Other',
];

const questionCategories = [
  'Debugging',
  'Concepts',
  'Code Review',
  'Career',
  'Other',
];

const typeQuestion = 'question';
const typeReviewRequest = 'reviewRequest';

// only github.com repository links are stored for now
final _githubRepoPattern = RegExp(
  r'^https://github\.com/[\w.-]+/[\w.-]+/?$',
);

bool isGithubRepoUrl(String value) => _githubRepoPattern.hasMatch(value);
