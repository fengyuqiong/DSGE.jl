@userplot HistForecast

"""
```
histforecast(var, hist, forecast;
    start_date = hist.means[1, :date], end_date = forecast.means[end, :date],
    hist_label = \"History\", forecast_label = \"Forecast\",
    hist_color = :black, forecast_color = :red, bands_color = :blue,
    bands_pcts = union(which_density_bands(hist, uniquify = true),
                       which_density_bands(forecast, uniquify = true)),
    bands_style = :fan, label_bands = false, transparent_bands = true,
    tick_size = 2)
```

User recipe called by `plot_history_and_forecast`.

### Inputs

- `var::Symbol`: e.g. `obs_gdp`
- `hist::MeansBands`
- `forecast::MeansBands`

### Keyword Arguments

- `start_date::Date`
- `end_date::Date`
- `hist_label::String`
- `forecast_label::String`
- `hist_color`
- `forecast_color`
- `bands_color`
- `bands_pcts::Vector{String}`: which bands percentiles to plot
- `bands_style::Symbol`: either `:fan` or `:line`
- `label_bands::Bool`
- `transparent_bands::Bool`
- `tick_size::Int`: x-axis (time) tick size in units of years

Additionally, all Plots attributes (see docs.juliaplots.org/latest/attributes)
are supported as keyword arguments.
"""
histforecast

@recipe function f(hf::HistForecast;
                   start_date = hf.args[2].means[1, :date],
                   end_date = hf.args[3].means[end, :date],
                   hist_label = "History",
                   forecast_label = "Forecast",
                   hist_color = :black,
                   forecast_color = :red,
                   bands_color = :blue,
                   bands_pcts = union(which_density_bands(hf.args[2], uniquify = true),
                                      which_density_bands(hf.args[3], uniquify = true)),
                   bands_style = :fan,
                   label_bands = false,
                   transparent_bands = true,
                   tick_size = 2)
    # Error checking
    if length(hf.args) != 3 || typeof(hf.args[1]) != Symbol ||
        typeof(hf.args[2]) != MeansBands || typeof(hf.args[3]) != MeansBands

        error("histforecast must be given a Symbol and two MeansBands. Got $(typeof(hf.args))")
    end

    # Concatenate MeansBands
    var, hist, forecast = hf.args
    combined = cat(hist, forecast)
    dates = combined.means[:date]

    # Assign date ticks
    date_ticks = Base.filter(x -> start_date <= x <= end_date,    dates)
    date_ticks = Base.filter(x -> Dates.month(x) == 3,            date_ticks)
    date_ticks = Base.filter(x -> Dates.year(x) % tick_size == 0, date_ticks)
    xticks --> (date_ticks, map(Dates.year, date_ticks))

    # Bands
    sort!(bands_pcts, rev = true) # s.t. non-transparent bands will be plotted correctly
    inds = find(start_date .<= combined.bands[var][:date] .<= end_date)

    for (i, pct) in enumerate(bands_pcts)
        seriestype := :line

        x = combined.bands[var][inds, :date]
        lb = combined.bands[var][inds, Symbol(pct, " LB")]
        ub = combined.bands[var][inds, Symbol(pct, " UB")]

        if bands_style == :fan
            @series begin
                if transparent_bands
                    fillcolor := bands_color
                    fillalpha := 0.1
                else
                    if typeof(bands_color) in [Symbol, String]
                        bands_color = parse(Colorant, bands_color)
                    end
                    fillcolor := weighted_color_mean(0.1*i, bands_color, colorant"white")
                    fillalpha := 1
                end
                linealpha  := 0
                fillrange  := ub
                label      := label_bands ? "$pct Bands" : ""
                x, lb
            end
        elseif bands_style == :line
            # Lower bound
            @series begin
                linecolor := bands_color
                label     := label_bands ? "$pct LB" : ""
                x, lb
            end

            # Upper bound
            @series begin
                linecolor := bands_color
                label     := label_bands ? "$pct UB" : ""
                x, ub
            end
        else
            error("bands_style must be either :fan or :line. Got $bands_style")
        end
    end

    # Mean history
    @series begin
        seriestype :=  :line
        linewidth  --> 2
        linecolor  :=  hist_color
        label      :=  hist_label

        inds = intersect(find(start_date .<= dates .<= end_date),
                         find(hist.means[1, :date] .<= dates .<= hist.means[end, :date]))
        combined.means[inds, :date], combined.means[inds, var]
    end

    # Mean forecast
    @series begin
        seriestype :=  :line
        linewidth  --> 2
        linecolor  :=  forecast_color
        label      :=  forecast_label

        inds = intersect(find(start_date .<= dates .<= end_date),
                         find(hist.means[end, :date] .<= dates .<= forecast.means[end, :date]))
        combined.means[inds, :date], combined.means[inds, var]
    end
end

@userplot Hair

"""
```
hair(var, realized, initial_values, forecasts;
    hist_label = \"Realized\", forecast_label = \"Forecasts\",
    hist_color = :black, forecast_color = :red, forecast_palette = :none,
    tick_size = 2)
```

User recipe called by `hair_plot`.

### Inputs

- `var::Symbol`: e.g. `:obs_gdp`
- `initial_values::Vector{Float64}`: vector of initial forecast values (i.e. s_{T|T} or y_T). Needed to
  connect the forecast hairs to the realized data line
- `forecasts::Vector{MeansBands}`

### Keyword Arguments

- `hist_label::String`
- `forecast_label::String`
- `forecast_color`
- `forecast_palette`: if not `:none`, the hair colors will be chosen according
  to this palette; otherwise they will all be `forecast_color`. Values
  correspond to values of the Plots attribute `color_palette` (see
  docs.juliaplots.org/latest/attributes)
- `tick_size::Int`: x-axis (time) tick size in units of years

Additionally, all Plots attributes (see docs.juliaplots.org/latest/attributes)
are supported as keyword arguments.
"""
hair

@recipe function f(hp::Hair;
                   hist_label = "Realized",
                   forecast_label = "Forecasts",
                   hist_color = :black,
                   forecast_color = :red,
                   forecast_palette = :none,
                   tick_size = 2)
    # Error checking
    if length(hp.args) != 4 || typeof(hp.args[1]) != Symbol || typeof(hp.args[2]) != DataFrame ||
        !(typeof(hp.args[3]) <: AbstractVector) ||
        !(typeof(hp.args[4]) <: AbstractVector{MeansBands})

        error("hair must be given Tuple{Symbol, DataFrame, AbstractVector, AbstractVector{MeansBands}}. Got $(typeof(hf.args))")
    end

    if length(initial_values) != length(forecasts)
        error("Lengths of initial_values ($length(initial_values)) and forecasts ($length(forecasts)) do not match")
    end

    var, realized, initial_values, forecasts = hp.args

    # Assign date ticks
    date_ticks = Base.filter(x -> Dates.month(x) == 3,            realized[:date])
    date_ticks = Base.filter(x -> Dates.year(x) % tick_size == 0, date_ticks)
    xticks --> (date_ticks, map(Dates.year, date_ticks))

    # Realized series
    @series begin
        seriestype := :line
        linewidth := 2
        linecolor := hist_color
        label     := hist_label

        realized[:date], realized[var]
    end

    # Forecasts
    for (initial_value, forecast) in zip(initial_values, forecasts)
        @series begin
            seriestype := :line
            linewidth  := 1
            label      := forecast == forecasts[1] ? forecast_label : ""
            if forecast_palette == :none
                linecolor := forecast_color
            else
                palette   := forecast_palette
            end

            initial_date = iterate_quarters(forecast.means[1, :date], -1)
            x = vcat(initial_date,  forecast.means[:date])
            y = vcat(initial_value, forecast.means[var])
            x, y
        end
    end
end

@userplot Shockdec

"""
```
shockdec(var, shockdec, trend, dettrend, hist, forecast, groups;
    start_date = shockdec.means[1, :date],
    end_date = shockdec.means[end, :date],
    hist_label = \"Detrended History\",
    forecast_label = \"Detrended Forecast\",
    hist_color = :black, forecast_color = :red, tick_size = 5)
```

User recipe called by `plot_shock_decomposition`.

### Inputs

- `var::Symbol`: e.g. `:obs_gdp`
- `shockdec::MeansBands`
- `trend::MeansBands`
- `dettrend::MeansBands`
- `hist::MeansBands`
- `forecast::MeansBands`
- `groups::Vector{ShockGroup}`

### Keyword Arguments

- `start_date::Date`
- `end_date::Date`
- `hist_label::String`
- `forecast_label::String`
- `hist_color`
- `forecast_color`
- `tick_size::Int`: x-axis (time) tick size in units of years

Additionally, all Plots attributes (see docs.juliaplots.org/latest/attributes)
are supported as keyword arguments.
"""
shockdec

@recipe function f(sd::Shockdec;
                   start_date = sd.args[2].means[1, :date],
                   end_date = sd.args[2].means[end, :date],
                   hist_label = "Detrended History",
                   forecast_label = "Detrended Forecast",
                   hist_color = :black,
                   forecast_color = :red,
                   tick_size = 5)
    # Error checking
    if length(sd.args) != 7 || typeof(sd.args[1]) != Symbol ||
        typeof(sd.args[2]) != MeansBands || typeof(sd.args[3]) != MeansBands ||
        typeof(sd.args[4]) != MeansBands || typeof(sd.args[5]) != MeansBands ||
        typeof(sd.args[6]) != MeansBands || typeof(sd.args[7]) != Vector{ShockGroup}

        error("shockdec must be given a Symbol, five MeansBands, and a Vector{ShockGroup}. Got $(typeof(sd.args))")
    end

    var, shockdec, trend, dettrend, hist, forecast, groups = sd.args

    # Construct DataFrame with detrended mean, deterministic trend, and all shocks
    df = DSGE.prepare_means_table_shockdec(shockdec, trend, dettrend, var,
                                      mb_hist = hist, mb_forecast = forecast,
                                      detexify_shocks = false,
                                      groups = groups)
    dates = df[:date]
    xnums = (1:length(dates)) - 0.5

    # Assign date ticks
    inds = intersect(find(x -> start_date .<= x .<= end_date,  dates),
                     find(x -> Dates.month(x) == 3,            dates),
                     find(x -> Dates.year(x) % tick_size == 0, dates))
    xticks --> (xnums[inds], map(Dates.year, dates[inds]))

    # Shock contributions
    @series begin
        labels    = map(x -> x.name,  groups)
        cat_names = map(Symbol, labels)
        colors    = map(x -> x.color, groups)
        ngroups   = length(groups)

        labels     --> reshape(labels, 1, ngroups)
        color      --> reshape(colors, 1, ngroups)
        linealpha  --> 0
        bar_width  --> 1
        legendfont --> Plots.Font("sans-serif", 5, :hcenter, :vcenter, 0.0, colorant"black")

        inds = find(start_date .<= dates .<= end_date)
        x = df[inds, :date]
        y = convert(Array, df[inds, cat_names])
        StatPlots.GroupedBar((x, y))
    end

    seriestype := :line
    linewidth  := 2
    ylim       := :auto

    # Detrended mean history
    @series begin
        linecolor := hist_color
        label     := hist_label

        inds = intersect(find(start_date .<= dates .<= end_date),
                         find(hist.means[1, :date] .<= dates .<= hist.means[end, :date]))
        xnums[inds], df[inds, :detrendedMean]
    end

    # Detrended mean forecast
    @series begin
        linecolor := forecast_color
        label     := forecast_label

        inds = intersect(find(start_date .<= dates .<= end_date),
                         find(hist.means[end, :date] .<= dates .<= forecast.means[end, :date]))
        xnums[inds], df[inds, :detrendedMean]
    end
end