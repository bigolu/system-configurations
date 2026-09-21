#!/usr/bin/env nu

def --wrapped main [...args] {
	let start_commit = if ($args | is-not-empty) and not (is-flag $args.0) { $args.0 } else { null }
		| do {
			let start_commit_abbreviation = $in
		  if $start_commit_abbreviation == null {
				# Rebase all the commits I haven't pushed yet.
				#
				# @{push} only exists if the branch has been pushed before.
				let refs = if (git rev-parse '@{push}' | complete).exit_code == 0 {
					[ '@{push}' ]
				} else {
					git rev-parse --remotes | lines
				}
				git merge-base HEAD ...$refs
			} else if ($start_commit_abbreviation | str length) <= 2 {
				# The argument is probably a number specifying how many commits from HEAD I want to
				# rebase.
				$"HEAD~($start_commit_abbreviation)"
			} else {
				# The argument is a commit-ish specifying the first commit to be included in the
				# rebase.
				$"($start_commit_abbreviation)^"
			}
		}

	let flags = $args | skip until { is-flag }

	# Save a reference to the commit we were on before the rebase started, in case we
	# want to go back. To restore from this point use: git reset --hard refs/bigolu/ir-backup
	git update-ref refs/bigolu/ir-backup HEAD

	git rebase --interactive ...$flags $start_commit
}

def is-flag [arg?: string]: oneof<string, nothing> -> bool {
	$in 
		| default $arg
		| str starts-with '-'
}
