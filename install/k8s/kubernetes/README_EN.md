# Quantanexus

Quantanexus is a Kubernetes distribution focused on providing a robust infrastructure for running containerized workloads. It includes pre-configured networking plugins and essential components for enterprise-grade deployments.

## Features

- **Multiple CNI Support**: Choose from popular networking solutions:
  - `flannel`
  - `kubeovn`
  - `cilium`
  - `calico`
- **BGP Support**: Enhanced networking capabilities with BGP support for CNI plugins that support it
- **Virtualization Ready**: Comes with `kubevirt` installed by default for running virtual machines alongside containers
- **Private Registry**: Uses `https://h.hi168.com` as the default container image registry

## Kubernetes Version Support

The following table shows the Kubernetes version support matrix for Quantanexus:

| Kubernetes Version | Support Status | Notes |
|-------------------|----------------|-------|
| 1.28.x | ✅ Full Support | Recommended version |
| 1.29.x | ✅ Full Support | Recommended version |
| 1.30.x | ✅ Full Support | Recommended version |
| 1.27.x | ✅ Full Support | Fully tested and supported |
| 1.26.x | ⚠️ Limited Support | Some features may not be available |
| < 1.26 | ❌ Not Supported | Unsupported versions |

## Getting Started

### Prerequisites

- Kubernetes cluster (v1.28+ recommended for full feature support)
- kubectl configured to access your cluster
- Helm 3.x (for some components)

### Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd quantanexus
```

2. Configure your preferred CNI plugin in the `values.yaml` or via command line:
```bash
# Example for installing with Cilium
helm install quantanexus . --set cni.plugin=cilium
```

3. Apply the manifests:
```bash
kubectl apply -f manifests/
```

### Configuration Options

| Parameter | Description | Default |
|----------|-------------|---------|
| `cni.plugin` | CNI plugin to use (flannel, kubeovn, cilium, calico) | `cilium` |
| `network.bgp.enabled` | Enable BGP networking | `false` |
| `kubevirt.enabled` | Enable KubeVirt virtualization | `true` |
| `registry.url` | Default container registry | `https://h.hi168.com` |

## Networking

Quantanexus supports multiple CNI plugins to suit different networking requirements:

- **Flannel**: Simple overlay network
- **Kube-OVN**: Feature-rich networking with subnet management
- **Cilium**: eBPF-based networking and security
- **Calico**: Policy-driven networking

To enable BGP features, set `network.bgp.enabled=true` when using a compatible CNI plugin.

## Virtualization

KubeVirt is included by default, allowing you to run virtual machines as Kubernetes workloads. This enables hybrid application deployments combining containers and VMs.

## Registry

All images are pulled from the private registry at `https://h.hi168.com` by default. You can customize this in your deployment configurations.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a pull request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

For issues and feature requests, please open an issue on the GitHub repository.