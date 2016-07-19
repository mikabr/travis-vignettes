set_env_var <- function(repo_slug, name, value, public = FALSE) {
  repo_url <- sprintf("https://api.travis-ci.org/repos/%s", repo_slug)
  repo <- GET(repo_url)
  repo_id <- jsonlite::fromJSON(rawToChar(repo$content))$id
  var_data <- list(
    "name" = name,
    "value" = value,
    "public" = public
  )
  # TODO: get github oauth token first
  env_vars_url <- sprintf(
    "https://api.travis-ci.org/settings/env_vars?repository_id=%s", repo_id
  )
  POST(env_vars_url, body = jsonlite::toJSON(var_data, auto_unbox = TRUE))
}


setup_travis <- function(owner, repo, author_email) {

  repo_slug <- sprintf("%s/%s", owner, repo)

  # TODO: get github oath token

  # generate deploy key pair
  key <- openssl::rsa_keygen()  # TOOD: num bits?
  public_key <- as.list(key)$pubkey

  # add public key to repo deploy keys on GitHub
  key_data <- list(
    "title" = "travis",  # TODO: put in datetime?
    "key" = as.list(public_key)$ssh,
    "read_only" = FALSE
  )
  # github::interactive.login()
  # TODO: auth problems, reuse oauth token with travis
  github::create.repository.key(owner, repo,
                                jsonlite::toJSON(key_data, auto_unbox = TRUE))

  # generate random variables for encryption
  enc_id <- stringi::stri_rand_strings(1, 12)
  tempkey <- openssl::rand_bytes(32)
  iv <- openssl::rand_bytes(16)

  # encrypt private key using tempkey and iv
  openssl::write_pem(key, "deploy_key")
  blob <- openssl::aes_cbc_encrypt("deploy_key", tempkey, iv)
  writeBin(blob, file("deploy_key.enc", "wb")) # TODO: write problems

  # add tempkey and iv as secure environment variables on travis
  set_env_var(repo_slug, sprintf("encrypted_%s_key", enc_id), tempkey)
  set_env_var(repo_slug, sprintf("encrypted_%s_iv", enc_id), iv)

  # write travis yaml
  # TODO: modify existing yaml
  yaml <- sprintf(
    'language: r
env:
  global:
    - AUTHOR_EMAIL=%s
    - ENCRYPTION_LABEL=%s
before_install:
  - cd testpackage
after_success:
  - chmod 755 ../.push_gh_pages.sh
  - ../.push_gh_pages.sh',
    author_email, var_id)
  writeLines(yaml, ".travis.yml")

}
