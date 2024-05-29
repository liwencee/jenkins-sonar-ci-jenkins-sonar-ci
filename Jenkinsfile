pipeline {
    
	agent any
	
	tools {
        maven "Maven3"
        jdk "OracleJDK11"
    }
	
	
    stages{
        
        stage('Build'){
            steps {
                sh 'mvn clean install -DskipTests'
            }

        }

        stage('Unit Test'){
            steps {
                sh 'mvn test'
            }
        }
		
        stage ('Checkstyle: Code Analysis'){
            steps {
                sh 'mvn checkstyle:checkstyle'
            }
            post {
                success {
                    echo 'Generated Analysis Result'
                }
            }
        }

        stage('SonarQube: Code Analysis') {
          
		  environment {
             scannerHome = tool 'sonar-scanner'
          }

          steps {
            withSonarQubeEnv('sonarserver') {
               sh '''${scannerHome}/bin/sonar-scanner -Dsonar.projectKey=darey_web_app \
                   -Dsonar.projectName=darey_web_app \
                   -Dsonar.projectVersion=1.0 \
                   -Dsonar.sources=src/ \
                   -Dsonar.java.binaries=target/test-classes/com/visualpathit/account/controllerTest/ \
                   -Dsonar.junit.reportsPath=target/surefire-reports/ \
                   -Dsonar.jacoco.reportsPath=target/jacoco.exec \
                   -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml'''
                } 
            }
        }
        
        stage ("Quality Gate") {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }   
            }
        }
    }
}