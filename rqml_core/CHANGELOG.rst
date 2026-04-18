^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Changelog for package rqml_core
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

3.26.41 (2026-04-18)
--------------------
* destroy plugin on close
  Matches behavior observed when plugins are restored from a config and
  initialization happens in PluginManager::factoryFn instead of
  createPlugin
* Contributors: dzajac

3.26.40 (2026-04-17)
--------------------
* Initial release.
* Contributors: Stefan Fabian
