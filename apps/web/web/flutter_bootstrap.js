{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Never expose Flutter's semantics visualization in production. The
    // accessibility tree remains available to assistive technologies.
    debugShowSemanticsNodes: false,
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
