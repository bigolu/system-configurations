#!/usr/bin/env nu

let new_url = git remote get-url origin
| str replace --regex '(http.*://)([^/]+)/(.+)$' 'git@${2}:${3}'
| if not ($in ends-with '.git') {
  $"($in).git"
} else {
  $in
}

input --numchar 1 $"Does this new url look fine? \(y/n): ($new_url)"
| str lowercase
| if $in == y {
  git remote set-url origin $new_url
  print 'Git remote updated.'
} else {
  print 'Git remote unchanged.'
}
