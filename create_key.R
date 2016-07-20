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
    "title" = paste("travis", Sys.time()),
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
  openssl::write_pem(key, "deploy_key", password = NULL)
  blob <- openssl::aes_cbc_encrypt("deploy_key", tempkey, iv)
  attr(blob, "iv") <- NULL
  #openssl::base64_encode(blob)
  #writeBin(openssl::base64_encode(blob), "deploy_key.enc")
  writeBin(blob, "deploy_key.enc")

  # add tempkey and iv as secure environment variables on travis
  set_env_var(repo_slug, sprintf("encrypted_%s_key", enc_id),
              paste(tempkey, collapse = ""))
  set_env_var(repo_slug, sprintf("encrypted_%s_iv", enc_id),
              paste(iv, collapse = ""))

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
    author_email, enc_id)
  writeLines(yaml, ".travis.yml")

}
