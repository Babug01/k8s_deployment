pipeline {
  parameters {
    booleanParam(name: 'checkout', defaultValue: false, description: 'checkout the codebase')
    booleanParam(name: 'deploy_Env', defaultValue: false, description: 'deploy the required GKE env')
    booleanParam(name: 'destroy_Env', defaultValue: false, description: 'destroy the GKE env')
	}
  agent any
  options {
       skipDefaultCheckout true
     }
	
  environment {
        secret_key = credentials('secret_key')
        access_key = credentials('access_key')
		git = credentials('GitHub')
    }
  triggers {
        pollSCM 'H/10 * * * *'
    }	
stages { 
      stage('Checkout'){
        when { expression { params.checkout == true }}
	    steps {
           // Get the terraform plan
           checkout changelog: false, poll: true, scm: [$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'CleanBeforeCheckout']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: 'GitHub', url: 'https://github.com/Babug01/k8s_deployment.git']]]
		}
      }

      stage('Terraform init'){
          when { expression { params.deploy_Env == true }}
		   steps { 
              // Initialize the plan 
              sh  """
                cd terraform
                terraform init -input=false
                 """
		  }
      }
	  
     stage('Terraform plan'){
          when { expression { params.deploy_Env == true }}
	steps {          
             sh (script:"cd terraform && terraform plan -out=tfplan -input=false -var 'secret_key='$secret_key  -var 'access_key='$access_key")
				}
     }
     
     stage('Terraform apply'){
          when { expression { params.deploy_Env == true }}
			steps {   
             // Apply the plan
             sh  """  
                cd terraform
	 	        terraform apply -input=false -auto-approve "tfplan"
                """
             sh (script:"cd terraform && terraform plan -destroy -out destroy.tfplan -input=false -var 'secret_key='$secret_key  -var 'access_key='$access_key")
		}
     }
	 
     stage('Terraform Destroy'){
          when { expression { params.destroy_Env == true }}
            steps {       
                 // Apply the delete plan
                 sh  """  
                    cd terraform
		            rm -Rf terraform.tfstate.d/
	 	            terraform apply -input=false -auto-approve destroy.tfplan
                    """
		 }
     }
    }
}
