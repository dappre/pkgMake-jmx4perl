#!groovy

/*
 * This work is protected under copyright law in the Kingdom of
 * The Netherlands. The rules of the Berne Convention for the
 * Protection of Literary and Artistic Works apply.
 * Digital Me B.V. is the copyright owner.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Load Jenkins shared libraries common to all projects
def libLazy = [
	remote:			'https://github.com/digital-me/jenkins-lib-lazy.git',
	branch:			'stable',
	credentialsId:	null,
]

library(
	identifier: "libLazy@${libLazy.branch}",
	retriever: modernSCM([
		$class: 		'GitSCMSource',
		remote: 		libLazy.remote,
		credentialsId:	libLazy.credentialsId
	])
)

// Load Jenkins shared libraries to customize this project
def libCustom = [
	remote:			'ssh://git@code.in.digital-me.nl:2222/DEVops/JenkinsLibCustom.git',
	branch:			'stable',
	credentialsId:	'bot-ci-dgm-rsa',
]

library(
	identifier: "libCustom@${libCustom.branch}",
	retriever: modernSCM([
		$class:			'GitSCMSource',
		remote:			libCustom.remote,
		credentialsId:	libCustom.credentialsId
	])
)

// Load Jenkins shared libraries for rpmMake utils
def libRpmMake = [
	remote:			'https://github.com/digital-me/rpmMake.git',
	branch:			'stable',
	credentialsId:	null,
]

library(
	identifier: "libRpmMake@${libRpmMake.branch}",
	retriever: modernSCM([
		$class:			'GitSCMSource',
		remote:			libRpmMake.remote,
		credentialsId:	libRpmMake.credentialsId
	])
)

// Define the remotes and the working and deploy branches
def remote = 'origin'
def workingBranch = 'main'
def releaseBranch = 'stable'

// Initialize configuration
lazyConfig(
	name: 'pkgmake',
	inLabels: [ /*'centos6',*/ 'centos7', /*'ubuntu16',*/ ],
	env: 		[
		VERSION: false,
		RELEASE: false,
		DRYRUN: false,
		TARGET_DIR: 'target',
		GIT_CRED: 'bot-ci-dgm-rsa',
		DEPLOY_USER: 'root',
		DEPLOY_HOST: 'orion1.boxtel',
		DEPLOY_DIR: '/var/mrepo',
		DEPLOY_REPO: 'local',
		DEPLOY_CRED: 'bot-ci-dgm-rsa',
	],
	noIndex:	"(${releaseBranch}|.+_.+)",	// Avoid automatic indexing for release and private branches
	compressLog: false,
	timestampsLog: true,
)

// Validate the project (parsing mostly)
lazyStage {
	name = 'validate'
	onlyif = ( lazyConfig['branch'] != releaseBranch ) // Skip when releasing
	tasks = [
		pre: {
			def version = gitLastTag('*.*')
			if (env.VERSION.toString() != 'true' && env.VERSION.toString() != 'false') {
				version = env.VERSION.toString()
			}
			def release = '1'
			if (version ==~ /.+-.+/) {
				release = version.split('-')[1]
				version = version - ~/-.+$/
			}
			currentBuild.displayName = "#${env.BUILD_NUMBER} ${version}-${release}"
		},
		run: {
			def version = gitLastTag('*.*')
			if (env.VERSION.toString() != 'true' && env.VERSION.toString() != 'false') {
				version = env.VERSION.toString()
			}
			if (version ==~ /.+-.+/) {
				version = version - ~/-.+$/
			}
			sh("make check VERSION=${version}")
		},
		in: '*', on: 'docker'
	]
}

// Build and test the package(s) inside Docker
lazyStage {
	name = 'test'
	onlyif = ( lazyConfig['branch'] != releaseBranch ) // Skip when releasing
	tasks = [
		run: {
			def version = gitLastTag('*.*')
			if (env.VERSION.toString() != 'true' && env.VERSION.toString() != 'false') {
				version = env.VERSION.toString()
			}
			def release = '1'
			if (version ==~ /.+-.+/) {
				release = version.split('-')[1]
				version = version - ~/-.+$/
			}
			sh(
"""
DIST="\${LAZY_LABEL}-\$(arch)"
make \
VERSION=${version} \
RELEASE=${release} \
TARGET_DIR="\$(pwd)/\${TARGET_DIR}" \
DISTS_DIR="\$(pwd)/\${TARGET_DIR}/dists/\${DIST}" \
LOG_FILE=/dev/stdout
"""
			)
			sh(
"""
DIST="\${LAZY_LABEL}-\$(arch)"
cd "\${TARGET_DIR}/dists/\${DIST}"
sudo yum -y install *.rpm
"""
			)
		},
		in: '*', on: 'docker',
	]
}

// Build and store the package(s) for deployement
lazyStage {
	name = 'package'
	onlyif = ( lazyConfig['branch'] == releaseBranch )
	tasks = [
		run: {
			def version = gitLastTag('*.*')
			if (env.VERSION.toString() != 'true' && env.VERSION.toString() != 'false') {
				version = env.VERSION.toString()
			}
			def release = '1'
			if (version ==~ /.+-.+/) {
				release = version.split('-')[1]
				version = version - ~/-.+$/
			}
			currentBuild.displayName = "#${env.BUILD_NUMBER} ${version}-${release}"
			sh(
"""
DIST="\${LAZY_LABEL}-\$(arch)"
make \
VERSION=${version} \
RELEASE=${release} \
TARGET_DIR="\$(pwd)/\${TARGET_DIR}" \
DISTS_DIR="\$(pwd)/\${TARGET_DIR}/dists/\${DIST}" \
LOG_FILE=/dev/stdout
"""
			)
		},
		in: '*', on: 'docker',
		post: {
			archiveArtifacts(artifacts: "${env.TARGET_DIR}/dists/**", allowEmptyArchive: false)
		},
	]
}

// Release stage only if criteria are met
lazyStage {
	name = 'release'
	onlyif = ( lazyConfig['branch'] == workingBranch && lazyConfig.env.RELEASE )
	// Ask version if release flag and set and we are in the branch to fork release from
	input = [
		message: 'Version string',
		parameters: [string(
			defaultValue: "${env.VERSION}",
			description: "Version to be release: '*build*', 'micro', 'minor', 'major' or a specific string (i.e.: 1.2.3-4)",
			name: 'VERSION'
		)]
	]
	tasks = [
		run: {
			gitAuth(env.GIT_CRED, {
				// Define next version based on optional input
				def currentVersion = gitLastTag('*.*')
				def nextVersion = null
				if (env.lazyInput && env.lazyInput != currentVersion) {
					if (env.lazyInput ==~ /[a-z]+/) {
						nextVersion = bumpVersion(env.lazyInput, currentVersion)
					} else {
						nextVersion = env.lazyInput
					}
				} else {
					nextVersion = bumpVersion('build', currentVersion)
				}
				// Merge changes from working into release branch
				gitMerge(workingBranch, releaseBranch)
				// Tag and publish changes in release branch
				gitTag("${nextVersion}")
				gitPush(remote, "${releaseBranch} ${nextVersion}")
				// Update the displayed version for this build
				currentVersion = gitLastTag('*.*')
				currentBuild.displayName = "#${env.BUILD_NUMBER} ${currentVersion}"
			})
		},
		// Can not be done in parallel
	]
}

// Deliver the site on each environment
lazyStage {
	name = 'testing'
	onlyif = ( lazyConfig['branch'] == releaseBranch )
	input = 'Deploy to systemtest?'
	tasks = [
		pre: {
			unarchive(mapping:["${env.TARGET_DIR}/" : '.'])
		},
		run: 'repo_sync.sh', // Only to get the script copied from the lib
		post: {
			sshagent(credentials: [env.DEPLOY_CRED]) {
				sh("./lazyDir/testing/repo_sync.sh"
					+ " -s '${env.TARGET_DIR}/dists'"
					+ " '${env.DEPLOY_USER}@${env.DEPLOY_HOST}:${env.DEPLOY_DIR}'"
					+ " '${env.DEPLOY_REPO}-testing'"
				)
			}
		},
		// Can not be done in parallel
	]
}

lazyStage {
	name = 'stable'
	onlyif = ( lazyConfig['branch'] == releaseBranch )
	input = 'Deploy to production?'
	tasks = [
		pre: {
			unarchive(mapping:["${env.TARGET_DIR}/" : '.'])
		},
		run: 'repo_sync.sh', // Only to get the script copied from the lib
		post: {
			sshagent(credentials: [env.DEPLOY_CRED]) {
				sh("./lazyDir/stable/repo_sync.sh"
					+ " -s '${env.TARGET_DIR}/dists'"
					+ " -o '${env.DEPLOY_REPO}-testing'"
					+ " '${env.DEPLOY_USER}@${env.DEPLOY_HOST}:${env.DEPLOY_DIR}'"
					+ " '${env.DEPLOY_REPO}'"
				)
			}
		},
		// Can not be done in parallel
	]
}
