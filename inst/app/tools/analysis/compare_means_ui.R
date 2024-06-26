## choice lists for compare means
cm_alt <- list("Two sided" = "two.sided", "Less than" = "less", "Greater than" = "greater")
cm_samples <- c("independent" = "independent", "paired" = "paired")
cm_adjust <- c("None" = "none", "Bonferroni" = "bonf")
cm_plots <- c("Scatter" = "scatter", "Box" = "box", "Density" = "density", "Bar" = "bar")

## list of function arguments
cm_args <- as.list(formals(compare_means))

## list of function inputs selected by user
cm_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  cm_args$data_filter <- if (input$show_filter) input$data_filter else ""
  cm_args$dataset <- input$dataset
  for (i in r_drop(names(cm_args))) {
    cm_args[[i]] <- input[[paste0("cm_", i)]]
  }
  cm_args
})

###############################
# Compare means
###############################
output$ui_cm_var1 <- renderUI({
  vars <- c("None" = "", groupable_vars())
  isNum <- .get_class() %in% c("integer", "numeric", "ts")

  ## can't use unique here - removes variable type information
  vars <- c(vars, varnames()[isNum]) %>% .[!duplicated(.)]

  selectInput(
    inputId = "cm_var1",
    label = "Select a factor or numeric variable:",
    choices = vars,
    selected = state_single("cm_var1", vars),
    multiple = FALSE
  )
})

output$ui_cm_var2 <- renderUI({
  if (not_available(input$cm_var1)) {
    return()
  }
  isNum <- .get_class() %in% c("integer", "numeric", "ts")
  vars <- varnames()[isNum]

  if (input$cm_var1 %in% vars) {
    ## when cm_var1 is numeric comparisons for multiple variables are possible
    vars <- vars[-which(vars == input$cm_var1)]
    if (length(vars) == 0) {
      return()
    }

    selectizeInput(
      inputId = "cm_var2", label = "Numeric variable(s):",
      selected = state_multiple("cm_var2", vars, isolate(input$cm_var2)),
      choices = vars, multiple = TRUE,
      options = list(placeholder = "None", plugins = list("remove_button", "drag_drop"))
    )
  } else {
    ## when cm_var1 is not numeric comparisons are across levels/groups
    vars <- c("None" = "", vars)
    selectInput(
      "cm_var2", "Numeric variable:",
      selected = state_single("cm_var2", vars),
      choices = vars,
      multiple = FALSE
    )
  }
})

output$ui_cm_comb <- renderUI({
  if (not_available(input$cm_var1)) {
    return()
  }

  if (.get_class()[[input$cm_var1]] == "factor") {
    levs <- .get_data()[[input$cm_var1]] %>% levels()
  } else {
    levs <- c(input$cm_var1, input$cm_var2)
  }

  if (length(levs) > 2) {
    cmb <- combn(levs, 2) %>% apply(2, paste, collapse = ":")
  } else {
    return()
  }

  selectizeInput(
    "cm_comb",
    label = "Choose combinations:",
    choices = cmb,
    selected = state_multiple("cm_comb", cmb, cmb[1]),
    multiple = TRUE,
    options = list(placeholder = "Evaluate all combinations", plugins = list("remove_button", "drag_drop"))
  )
})


output$ui_compare_means <- renderUI({
  req(input$dataset)
  tagList(
    wellPanel(
      conditionalPanel(
        uiOutput("ui_cm_var1"),
        uiOutput("ui_cm_var2"),
        condition = "input.tabs_compare_means == 'Summary'",
        uiOutput("ui_cm_comb"),
        selectInput(
          inputId = "cm_alternative", label = "Alternative hypothesis:",
          choices = cm_alt,
          selected = state_single("cm_alternative", cm_alt, cm_args$alternative)
        ),
        sliderInput(
          "cm_conf_lev", "Confidence level:",
          min = 0.85, max = 0.99, step = 0.01,
          value = state_init("cm_conf_lev", cm_args$conf_lev)
        ),
        checkboxInput("cm_show", "Show additional statistics", value = state_init("cm_show", FALSE)),
        radioButtons(
          inputId = "cm_samples", label = "Sample type:", cm_samples,
          selected = state_init("cm_samples", cm_args$samples),
          inline = TRUE
        ),
        radioButtons(
          inputId = "cm_adjust", label = "Multiple comp. adjustment:", cm_adjust,
          selected = state_init("cm_adjust", cm_args$adjust),
          inline = TRUE
        ),
        radioButtons(
          inputId = "cm_test", label = "Test type:",
          c("t-test" = "t", "Wilcox" = "wilcox"),
          selected = state_init("cm_test", cm_args$test),
          inline = TRUE
        )
      ),
      conditionalPanel(
        condition = "input.tabs_compare_means == 'Plot'",
        selectizeInput(
          inputId = "cm_plots", label = "Select plots:",
          choices = cm_plots,
          selected = state_multiple("cm_plots", cm_plots, "scatter"),
          multiple = TRUE,
          options = list(placeholder = "Select plots", plugins = list("remove_button", "drag_drop"))
        )
      )
    ),
    help_and_report(
      modal_title = "Compare means",
      fun_name = "compare_means",
      help_file = inclMD(file.path(getOption("radiant.path.basics"), "app/tools/help/compare_means.md"))
    )
  )
})

cm_plot <- reactive({
  list(plot_width = 650, plot_height = 400 * max(length(input$cm_plots), 1))
})

cm_plot_width <- function() {
  cm_plot() %>%
    (function(x) if (is.list(x)) x$plot_width else 650)
}

cm_plot_height <- function() {
  cm_plot() %>%
    (function(x) if (is.list(x)) x$plot_height else 400)
}

# output is called from the main radiant ui.R
output$compare_means <- renderUI({
  register_print_output("summary_compare_means", ".summary_compare_means", )
  register_plot_output(
    "plot_compare_means", ".plot_compare_means",
    height_fun = "cm_plot_height"
  )

  # two separate tabs
  cm_output_panels <- tabsetPanel(
    id = "tabs_compare_means",
    tabPanel("Summary", verbatimTextOutput("summary_compare_means")),
    tabPanel(
      "Plot",
      download_link("dlp_compare_means"),
      plotOutput("plot_compare_means", height = "100%")
    )
  )

  stat_tab_panel(
    menu = "Basics > Means",
    tool = "Compare means",
    tool_ui = "ui_compare_means",
    output_panels = cm_output_panels
  )
})

cm_available <- reactive({
  if (not_available(input$cm_var1) || not_available(input$cm_var2)) {
    return("This analysis requires at least two variables. The first can be of type\nfactor, numeric, or interval. The second must be of type numeric or interval.\nIf these variable types are not available please select another dataset.\n\n" %>% suggest_data("salary"))
  } else if (length(input$cm_var2) > 1 && .get_class()[input$cm_var1] == "factor") {
    " "
  } else if (input$cm_var1 %in% input$cm_var2) {
    " "
  } else {
    "available"
  }
})

.compare_means <- reactive({
  cmi <- cm_inputs()
  cmi$envir <- r_data
  do.call(compare_means, cmi)
})

.summary_compare_means <- reactive({
  if (cm_available() != "available") {
    return(cm_available())
  }
  if (input$cm_show) summary(.compare_means(), show = TRUE) else summary(.compare_means())
})

.plot_compare_means <- reactive({
  if (cm_available() != "available") {
    return(cm_available())
  }
  validate(need(input$cm_plots, "\n\n\n           Nothing to plot. Please select a plot type"))
  withProgress(message = "Generating plots", value = 1, {
    plot(.compare_means(), plots = input$cm_plots, shiny = TRUE)
  })
})

compare_means_report <- function() {
  if (is.empty(input$cm_var1) || is.empty(input$cm_var2)) {
    return(invisible())
  }
  figs <- FALSE
  outputs <- c("summary")
  inp_out <- list(list(show = input$cm_show), "")
  if (length(input$cm_plots) > 0) {
    outputs <- c("summary", "plot")
    inp_out[[2]] <- list(plots = input$cm_plots, custom = FALSE)
    figs <- TRUE
  }
  update_report(
    inp_main = clean_args(cm_inputs(), cm_args),
    fun_name = "compare_means",
    inp_out = inp_out,
    outputs = outputs,
    figs = figs,
    fig.width = cm_plot_width(),
    fig.height = cm_plot_height()
  )
}

download_handler(
  id = "dlp_compare_means",
  fun = download_handler_plot,
  fn = function() paste0(input$dataset, "_compare_means"),
  type = "png",
  caption = "Save compare means plot",
  plot = .plot_compare_means,
  width = cm_plot_width,
  height = cm_plot_height
)

observeEvent(input$compare_means_report, {
  r_info[["latest_screenshot"]] <- NULL
  compare_means_report()
})

observeEvent(input$compare_means_screenshot, {
  r_info[["latest_screenshot"]] <- NULL
  radiant_screenshot_modal("modal_compare_means_screenshot")
})

observeEvent(input$modal_compare_means_screenshot, {
  compare_means_report()
  removeModal() ## remove shiny modal after save
})
