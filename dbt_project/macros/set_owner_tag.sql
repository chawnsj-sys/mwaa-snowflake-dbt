-- 给模型打 owner 标签，用于生产环境追踪模型负责人
-- 使用方式: post_hook="{{ set_owner_tag('alice') }}"
{% macro set_owner_tag(owner_name) %}
    {% set tag_ref = target.database ~ '.ANALYTICS.OWNER' %}
    ALTER {{ 'VIEW' if config.get('materialized') == 'view' else 'TABLE' }} {{ this }} SET TAG {{ tag_ref }} = '{{ owner_name }}'
{% endmacro %}
