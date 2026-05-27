-- on-run-end Hook: 自动给 ANALYST_ROLE 授权 Gold 层表
{% macro grant_analyst_access() %}
    {% if target.name == 'prod' %}
        GRANT USAGE ON SCHEMA {{ target.database }}.{{ target.schema }}_analytics TO ROLE ANALYST_ROLE;
        GRANT SELECT ON ALL TABLES IN SCHEMA {{ target.database }}.{{ target.schema }}_analytics TO ROLE ANALYST_ROLE;
        GRANT SELECT ON ALL VIEWS IN SCHEMA {{ target.database }}.{{ target.schema }}_analytics TO ROLE ANALYST_ROLE;
    {% endif %}
{% endmacro %}
