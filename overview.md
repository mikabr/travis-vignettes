## Script run locally

- authenticate on github to get oauth token for github and travis APIs
- generate ssh key pair
- add public key to repo's deploy keys (using github API)
- generate random `var_id` and key+iv for encryption
- encrypt private key using key+iv
- add key+iv as secret environment variables with `var_id` in names (using travis API)
- make changes to `.travis.yml`:
  - add `var_id` as global environment variable
  - add `AUTHOR_EMAIL` as global environment variable
  - add `chmod 755 .push_gh_pages.sh; .push_gh_pages.sh` to `after_success` (once push script is merged into travis, instead add something like `push_docs: true`)

## Manually done locally

- push encrypted private key and `.travis.yml` to repo

## Script run on travis

- check for deploy conditions (on master, not pull request)
- use key+iv environment variables to decrypt private key
- add private key to local ssh keys
- set up git repo to push to `gh-pages`
- extract vignettes/docs files from package
- [render/build vignettes/docs]
- push results to `gh-pages`
