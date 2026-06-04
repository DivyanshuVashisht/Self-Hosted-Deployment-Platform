output "k3s_public_ip" {
  description = "The static public Elastic IP of the K3s cluster"
  value       = aws_eip.k3s.public_ip
}

output "instance_id" {
  description = "The EC2 instance ID"
  value       = aws_instance.k3s.id
}

output "ssh_instruction" {
  description = "Command to SSH into the server"
  value       = "ssh -i <your-private-key-file> ubuntu@${aws_eip.k3s.public_ip}"
}

output "kubeconfig_instruction" {
  description = "Command to retrieve the Kubeconfig file"
  value       = "scp -i <your-private-key-file> ubuntu@${aws_eip.k3s.public_ip}:/etc/rancher/k3s/k3s.yaml ./kubeconfig.yaml"
}
