{% set app = pillar.get('app', {}) %}
{% set name = app.get('name', 'demoapp') %}
{% set home = app.get('home', '/opt/' ~ name) %}

# Roll back by pointing `current` at the previous (second-newest) release and restarting.
# Usage: salt -C 'G@role:app' state.apply app.rollback
app_rollback_symlink:
  cmd.run:
    - name: |
        set -e
        prev=$(ls -1dt {{ home }}/releases/*/ 2>/dev/null | sed -n 2p)
        [ -n "$prev" ] || { echo "no previous release to roll back to" >&2; exit 1; }
        ln -sfn "${prev%/}" {{ home }}/current
        echo "rolled back to ${prev%/}"
    - shell: /bin/bash

app_rollback_restart:
  service.running:
    - name: {{ name }}
    - enable: True
    - restart: True
    - require:
      - cmd: app_rollback_symlink
