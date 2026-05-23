# Stratosphere

## Diagram

> Example of an AWS Based High Availability and Multi-Region Recovery (Pilot Light) Diagram

![Diagram Main](diagram/Diagram-1.png)

![Diagram Recovery](diagram/Diagram-2.png)

---

## CI/CD

> GitHub: [github-actions.yml](.github/workflows/github-actions.yml)

> GitLab: [.gitlab-ci.yml](.gitlab-ci.yml)

> Azure DevOps: [azure-pipelines.yml](azure-pipelines.yml)

> Bitbucket: [bitbucket-pipelines.yml](bitbucket-pipelines.yml)

---

## GitOps

### AWS

> EKS Argo-CD Cluster Deployment: [argo-cd.tf](infrastructure-aws/argo-cd/argo-cd.tf)

> EKS Argo-CD Sample Application Spec: [argo-cd-sample-application-spec.yaml](infrastructure-aws/argo-cd/argo-cd-sample-application-spec.yaml)


### GCP

> GKE Argo-CD Cluster Deployment: [argo-cd.tf](infrastructure-gcp/argo-cd/argo-cd.tf)

> GKE Argo-CD Sample Application Spec: [argo-cd-sample-application-spec.yaml](infrastructure-gcp/argo-cd/argo-cd-sample-application-spec.yaml)


### AZURE

> AKS Argo-CD Cluster Deployment: [argo-cd.tf](infrastructure-azure/argo-cd/argo-cd.tf)

> AKS Argo-CD Sample Application Spec: [argo-cd-sample-application-spec.yaml](infrastructure-azure/argo-cd/argo-cd-sample-application-spec.yaml)

---

## DevSecOps

> Jenkins Container: [compose.yaml](compose.yaml) / [jenkins.Dockerfile](jenkins.Dockerfile)

> Jenkins Pipeline with Vulnerability Scanner, SBOM and SAST: [Jenkinsfile](Jenkinsfile)

> Docker Local Vulnerability Scanner, SBOM and SAST Container: [compose.yaml](compose.yaml) / [vulnerabilities.Dockerfile](vulnerabilities.Dockerfile)

- Vulnerability Scanner: [Trivy](https://github.com/aquasecurity/trivy)

- SBOM: [Syft](https://github.com/anchore/syft) / [Grype](https://github.com/anchore/grype)

- SAST: [Semgrep](https://github.com/semgrep/semgrep)

---

## Components

> Note: Each component is built in a non-modular way to show the full implementation and to allow to independently create, update or delete them

## AWS

1. [VPC](infrastructure-aws/vpc/main.tf)
2. [VPC Flow Logs](infrastructure-aws/security/vpc-flow-logs/main.tf)
3. [Cloud Trail](infrastructure-aws/security/cloud-trail/main.tf)
4. [Network Load Balancers](infrastructure-aws/load-balancer/main.tf)
5. [Shield](infrastructure-aws/security/shield/main.tf)
6. [API Gateway](infrastructure-aws/api-gateway/http/main.tf)
7. [Databases](infrastructure-aws/databases/aurora/main.tf)
8. [Cache](infrastructure-aws/databases/elasticache/main.tf)
9. [EKS Cluster](infrastructure-aws/eks/main.tf)
10. [EKS Cluster IAM Permissions](infrastructure-aws/eks/permissions.tf)
11. [Kubernetes Namespaces](infrastructure-aws/workloads/devops/namespaces/main.tf)
12. [Kubernetes Secrets](infrastructure-aws/workloads/devops/secrets/main.tf)
13. [Helm Charts](infrastructure-aws/workloads/devops/charts/)
14. [CI/CD - Build Agents](infrastructure-aws/workloads/devops/build-agents/main.tf)
15. [Workload - Sample Game 2048 App](infrastructure-aws/workloads/applications/game-2048/main.tf)
16. [Rancher Instance](infrastructure-aws/rancher/main.tf)
17. [EKS Argo-CD](infrastructure-aws/argo-cd/argo-cd.tf)


## GCP

1. [VPC](infrastructure-gcp/vpc/main.tf)
2. [GKE Cluster](infrastructure-gcp/gke/main.tf)
3. [Workload - Sample Game 2048 Chart](infrastructure-gcp/workloads/devops/charts/game-2048/)
4. [Rancher Instance](infrastructure-gcp/rancher/main.tf)
5. [GKE Argo-CD](infrastructure-gcp/argo-cd/argo-cd.tf)


## AZURE

1. [VPC](infrastructure-azure/vpc/main.tf)
2. [AKS Cluster](infrastructure-azure/aks/main.tf)
3. [Workload - Sample Game 2048 Chart](infrastructure-azure/workloads/devops/charts/game-2048/)
4. [Rancher Instance](infrastructure-azure/rancher/main.tf)
5. [AKS Argo-CD](infrastructure-azure/argo-cd/argo-cd.tf)
