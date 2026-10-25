{% set app = pillar.get('app', {}) %}
{% set name = app.get('name', 'demoapp') %}
{% set version = app.get('version', '0.0.0') %}
{% set user = app.get('user', 'demoapp') %}
{% set home = app.get('home', '/opt/' ~ name) %}

app_user:
  user.present:
    - name: {{ user }}
    - system: True
    - shell: /sbin/nologin
    - home: {{ home }}

app_dirs:
  file.directory:
    - names:
      - {{ home }}
      - {{ home }}/releases
      - /var/log/{{ name }}
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - user: app_user

# Release is extracted into a versioned directory, then `current` is
# switched atomically - old releases stay available for instant rollback.
app_release:
  archive.extracted:
    - name: {{ home }}/releases/{{ version }}
    - source: salt://app/files/app-{{ version }}.tar.gz
    - skip_verify: True
    - user: {{ user }}
    - group: {{ user }}
    - enforce_toplevel: False
    - require:
      - file: app_dirs

app_current_symlink:
  file.symlink:
    - name: {{ home }}/current
    - target: {{ home }}/releases/{{ version }}
    - force: True
    - require:
      - archive: app_release

app_config:
  file.managed:
    - name: /etc/{{ name }}/app.conf
    - source: salt://app/files/app.conf.jinja
    - template: jinja
    - makedirs: True
    - user: root
    - group: {{ user }}
    - mode: '0640'
    - context:
        port: {{ app.get('port', 8080) }}
        log_level: {{ app.get('log_level', 'info') }}

app_service_unit:
  file.managed:
    - name: /etc/systemd/system/{{ name }}.service
    - source: salt://app/files/app.service.jinja
    - template: jinja
    - mode: '0644'
    - context:
        name: {{ name }}
        user: {{ user }}
        home: {{ home }}

app_service:
  service.running:
    - name: {{ name }}
    - enable: True
    - reload: False
    - watch:
      - file: app_config
      - file: app_service_unit
      - file: app_current_symlink
    - require:
      - file: app_service_unit

# Keep only the 5 newest releases
app_prune_releases:
  cmd.run:
    - name: ls -1dt {{ home }}/releases/* | tail -n +6 | xargs -r rm -rf
    - onchanges:
      - file: app_current_symlink
