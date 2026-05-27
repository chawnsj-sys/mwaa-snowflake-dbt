-- 日期工具 Macro

{% macro days_since(date_column) %}
    datediff(day, {{ date_column }}, current_date())
{% endmacro %}

{% macro format_date(date_column) %}
    date_trunc('day', {{ date_column }})::date
{% endmacro %}

{% macro is_within_days(date_column, days) %}
    {{ date_column }} >= dateadd(day, -{{ days }}, current_date())
{% endmacro %}
