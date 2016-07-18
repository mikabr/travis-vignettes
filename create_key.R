travis_pubkey <- function(owner, repo) {
  url <- sprintf("https://api.travis-ci.org/repos/%s/%s/key", owner, repo)
  keystr <- gsub("RSA PUBLIC", "PUBLIC", jsonlite::fromJSON(url)$key)
  openssl::read_pubkey(textConnection(keystr))
}

setup_travis <- function(owner, repo, author_email) {

  # generate deploy key
  key <- openssl::rsa_keygen()  # TOOD: num bits?
  pubkey <- as.list(key)$pubkey
  deploy_key <- as.list(pubkey)$ssh

  # add deploy key to repo on GitHub
  key_data <- list(
    "title" = "travis",  # TODO: put in datetime
    "key" = deploy_key,
    "read_only" = FALSE
  )
  github::interactive.login()
  # TODO: 404
  github::create.repository.key(owner, repo,
                                jsonlite::toJSON(key_data, auto_unbox = TRUE))

  # get travis public key attached to this repository
  travis_key <- travis_pubkey(owner, repo)

  # encrypt deploy key as travis environment variable using travis key
  buf <- openssl::rsa_encrypt(charToRaw(sprintf("DEPLOY_KEY=%s", deploy_key)),
                              pubkey = travis_key)
  enc <- openssl::base64_encode(buf)

  # write travis yaml
  yaml <- sprintf(
    'language: r
env:
  - AUTHOR_EMAIL=%s
  - secure: "%s"
before_install:
  - cd testpackage
after_success:
  - chmod 755 ../.push_gh_pages.sh
  - ../.push_gh_pages.sh',
    author_email, enc)
  writeLines(yaml, ".travis.yml")

}
