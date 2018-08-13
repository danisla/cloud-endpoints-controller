## Development

This project uses the following build tools:

- [helm](https://helm.sh/)
- [dep](https://github.com/golang/dep)
- [skaffold](https://github.com/GoogleContainerTools/skaffold)
- [kustomize](https://github.com/kubernetes-sigs/kustomize)

1. Install the metacontroller:

```
make install-metacontroller
```

2. Install go dependencies:

```
dep ensure
```

3. Run in cluster with skaffold:

```
skaffold dev
```

## Testing

1. Run all tests:

```
make test
```

2. Stop tests:

```
make test-stop
```

## Building Container Image

1. Build image using container builder in current project:

```
make image
```