load('ext://helm_resource', 'helm_repo', 'helm_resource')

ctx = k8s_context()
if ctx.startswith('admin@talos-'):
    allow_k8s_contexts(ctx)

update_settings(k8s_upsert_timeout_secs=180)

def _get_object_name(object, name = None, kind = None, namespace = None, metadata=None):
    metadata = metadata or object.get('metadata', {}) or object
    name = name or metadata['name'].lower()
    kind = kind or object['kind'].lower()
    namespace = namespace or metadata.get('namespace', None)

    if namespace:
        return '{}:{}:{}'.format(name, kind, namespace.lower())
    else:
        return '{}:{}'.format(name, kind)

def _get_object_labels(object):
    label = object.get('metadata', {}).get('annotations', {}).get('tilt.dev/label')
    if not label:
        label = object.get('metadata', {}).get('namespace')
    return [label] if label else []

config.define_bool('flux-mode', usage='Use flux for helm instead of tilt')
options = config.parse()
flux_mode = options.get('flux-mode', False)

def process_stack(path):
    kustomized = local('cue cmd export ./...', quiet=True)
    config_maps, rest = filter_yaml(kustomized, kind='ConfigMap')
    helm_repos, rest = filter_yaml(kustomized, api_version='source.toolkit.fluxcd.io', kind='HelmRepository')
    helm_releases, rest = filter_yaml(rest, api_version='helm.toolkit.fluxcd.io', kind='HelmRelease')

    values_objects = {}
    for config_map in decode_yaml_stream(config_maps):
        metadata = config_map['metadata']
        name = metadata['name']
        namespace = metadata.get('namespace', None)
        data = config_map['data']

        contents = values_objects.setdefault(namespace, {}).setdefault(name, {})
        # TODO: When helm 3.19 comes out, we can replace this hack with just the object
        for key, value in data.items():
            contents_object = contents.setdefault(key, {})
            object = decode_yaml(value)
            for key, value in object.items():
                contents_object[key] = value

    for repo in decode_yaml_stream(helm_repos):
        metadata = repo['metadata']
        spec = repo['spec']
        helm_repo(
            metadata['name'],
            spec['url'],
            resource_name=_get_object_name(repo),
            labels=_get_object_labels(repo),
        )

    for release in decode_yaml_stream(helm_releases):
        metadata = release.get('metadata', {})
        namespace = metadata.get('namespace')
        spec = release['spec']
        chart = spec['chart']['spec']
        source_ref = chart['sourceRef']

        # Parse values
        values = spec.get('values', {})
        for value_source in spec.get('valuesFrom', []):
            namespace = value_source.get('namespace',  namespace)
            name = value_source['name']
            key = value_source['valuesKey']

            values.update(**values_objects.get(namespace, {}).get(name, {}).get(key, {}))

        flags = []
        if spec.get('install', {}).get('crds', None) == 'Skip':
            flags.append('--skip-crds')

        pod_readiness='wait'
        if metadata['name'].endswith('-crds'):
            pod_readiness='ignore'

        dependencies = [_get_object_name(source_ref, namespace=source_ref.get('namespace', namespace))]
        for dep in spec.get('dependsOn', []):
            dependencies.append(_get_object_name(
                dep,
                metadata=dep,
                kind='helmrelease',
                namespace=dep.get('namespace', namespace)
            ))
        if namespace:
            dependencies.append('{}:namespace'.format(namespace))

        helm_resource(
            _get_object_name(release),
            source_ref['name'] + '/' + chart['chart'],
            release_name=metadata['name'],
            namespace=metadata['namespace'],
            # TODO: When helm 3.19 comes out, we can replace this hack with just the object
            flags=flags + ['--set-json=' + '{}={}'.format(key, encode_json(value).replace('\n', '')) for key, value in values.items()],
            resource_deps=dependencies,
            pod_readiness=pod_readiness,
            labels=_get_object_labels(release),
        )

    k8s_yaml(rest)

    for object in decode_yaml_stream(rest):
        name = _get_object_name(object)
        k8s_resource(
            new_name=name,
            objects=[name],
            labels=_get_object_labels(object),
            )

    namespaces, rest = filter_yaml(rest, kind='namespace')
    for object in decode_yaml_stream(namespaces):
        k8s_resource(
            workload=_get_object_name(object),
            labels=[object['metadata']['name'],]
        )

    for object in decode_yaml_stream(rest):
        # Depend on namespace creation
        namespace = object['metadata'].get('namespace')
        if namespace:
            k8s_resource(
                workload=_get_object_name(object),
                resource_deps=['{}:namespace'.format(namespace)]
            )

    # filter_yaml on labels doesn't seem to work, soooo
    for resource in decode_yaml_stream(kustomized):
        api_group = resource.get('metadata', {}).get('annotations', {}).get('tilt.dev/crd')
        if api_group:
            crd_deps, _ = filter_yaml(rest, api_version=api_group)
            for dep in decode_yaml_stream(crd_deps):
                k8s_resource(
                    workload=_get_object_name(dep),
                    resource_deps=[_get_object_name(resource)]
                )

        port_forward = resource.get('metadata').get('annotations', {}).get('tilt.dev/port-forward')
        if port_forward:
            k8s_resource(
                workload=_get_object_name(resource),
                port_forwards=[port_forward]
            )

k8s_yaml('flux-system/gotk-components.yaml')

process_stack('.')
