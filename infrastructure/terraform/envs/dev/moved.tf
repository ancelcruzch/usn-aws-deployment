# Reorganización en módulos: si el código anterior (todo en la raíz de
# infrastructure/terraform) ya se aplicó, estos bloques le indican a Terraform
# que los recursos solo cambiaron de dirección y no deben recrearse.
# En un estado vacío no tienen efecto. Se pueden borrar después de que todo el
# equipo haya aplicado esta versión.

moved {
  from = module.vpc
  to   = module.network.module.vpc
}

moved {
  from = module.eks
  to   = module.cluster.module.eks
}

moved {
  from = aws_eks_addon.pod_identity_agent
  to   = module.cluster.aws_eks_addon.pod_identity_agent
}

moved {
  from = aws_iam_role.ebs_csi
  to   = module.cluster.aws_iam_role.ebs_csi
}

moved {
  from = aws_iam_role_policy_attachment.ebs_csi
  to   = module.cluster.aws_iam_role_policy_attachment.ebs_csi
}

moved {
  from = aws_eks_pod_identity_association.ebs_csi
  to   = module.cluster.aws_eks_pod_identity_association.ebs_csi
}

moved {
  from = aws_eks_addon.ebs_csi
  to   = module.cluster.aws_eks_addon.ebs_csi
}
