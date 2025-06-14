package holos

#ComponentConfig: Validators: {
	k8svalidate: {
		kind: "Command"
		// Note --path maps each resource to a top level field named by the kind.
		command: args: [
			"kubeconform",
			"-schema-location", "default",
			"-schema-location", "https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json",
			"-schema-location", "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/{{.NormalizedKubernetesVersion}}/{{.ResourceKind}}{{.KindSuffix}}.json",
			"-skip", "CustomResourceDefinition",
			"-summary",
		]
	}
	kube_linter: {
		kind: "Command"
		// Note --path maps each resource to a top level field named by the kind.
		command: args: [
			"kube-linter",
			"lint",
			"--config", ".kube-linter.yaml",
		]
	}
}
