scopes <- c("repo", "read:org", "user:email", "write:repo_hook")
ctx <- github::interactive.login(scopes = scopes)
github_token <- ctx$token$credentials$access_token

# TODO: 403
auth_travis <- httr::POST(
  "https://api.travis-ci.org/auth/github",
  httr::content_type_json(), httr::user_agent("Travis/1.0"),
  httr::accept("application/vnd.travis-ci.2+json"),
  data = jsonlite::toJSON(list("github_token" = github_token),
                          auto_unbox = TRUE)
)

travis_token <- jsonlite::fromJSON(rawToChar(auth_travis$content))$access_token

set_env_var <- function(repo_id, name, value, public = FALSE, token) {
  var_data <- list(
    "env_var" = list(
      "name" = name,
      "value" = value,
      "public" = public
    )
  )
  env_vars_url <- sprintf(
    "https://api.travis-ci.org/settings/env_vars?repository_id=%s", repo_id
  )
  req <- httr::POST(env_vars_url,
                    httr::add_headers(Authorization = paste("token", token)),
                    body = jsonlite::toJSON(var_data, auto_unbox = TRUE))
  assertthat::assert_that(req$status_code == 200)
  return(NULL)
}


setup_travis <- function(owner, repo, author_email) {

  repo_slug <- sprintf("%s/%s", owner, repo)

  # generate deploy key pair
  key <- openssl::rsa_keygen()  # TOOD: num bits?
  public_key <- as.list(key)$pubkey

  # add public key to repo deploy keys on GitHub
  key_data <- list(
    "title" = paste("travis", Sys.time()),
    "key" = as.list(public_key)$ssh,
    "read_only" = FALSE
  )
  create_key <- github::create.repository.key(
    owner, repo, jsonlite::toJSON(key_data, auto_unbox = TRUE)
  )
  assertthat::assert_that(create_key$ok)

  # generate random variables for encryption
  enc_id <- stringi::stri_rand_strings(1, 12)
  tempkey <- openssl::rand_bytes(32)
  iv <- openssl::rand_bytes(16)

  # encrypt private key using tempkey and iv
  openssl::write_pem(key, "deploy_key", password = NULL)
  blob <- openssl::aes_cbc_encrypt("deploy_key", tempkey, iv)
  attr(blob, "iv") <- NULL
  writeBin(blob, "deploy_key.enc")

  # add tempkey and iv as secure environment variables on travis
  repo <- httr::GET(
    sprintf("https://api.travis-ci.org/repos/%s", repo_slug),
    httr::add_headers(Authorization = paste("token", travis_token))
  )
  repo_id <- jsonlite::fromJSON(rawToChar(repo$content))$id
  set_env_var(repo_id, sprintf("encrypted_%s_key", enc_id),
                          paste(tempkey, collapse = ""), FALSE, travis_token)
  set_env_var(repo_id, sprintf("encrypted_%s_iv", enc_id),
              paste(iv, collapse = ""), FALSE, travis_token)

  # write travis yaml
  if (file.exists(".travis.yml")) {
    travis_yml <- yaml::yaml.load_file(".travis.yml")
  } else {
    travis_yml <- list("language" = "r")
  }
  travis_yml$env$global <- c(travis_yml$env$global,
                             paste0("AUTHOR_EMAIL=", author_email),
                             paste0("ENCRYPTION_LABEL=", enc_id))
  travis_yml$after_success <- c(travis_yml$before_install,
                                "cd testpackage",
                                "chmod 755 .push_gh_pages.sh",
                                "./.push_gh_pages.sh")
  writeLines(yaml::as.yaml(travis_yml), ".travis.yml")

}
