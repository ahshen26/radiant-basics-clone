## urls for menu
r_url_list <- getOption("radiant.url.list")
r_url_list[["Variable Analysis"]] <-
  list("tabs_correlation" = list("Summary" = "basics/correlation/", "Plot" = "basics/correlation/plot/"))
options(radiant.url.list = r_url_list)
rm(r_url_list)

## try http://127.0.0.1:3174/?url=basics/correlation/plot/&SSUID=local

## design menu
options(
  radiant.basics_ui =
    tagList(
      navbarMenu(
        "Basics",
        tags$head(
          tags$script(src = "www_basics/js/run_return.js")
        ),
        tabPanel("Variable Analysis", uiOutput("correlation"))
      )
    )
)

