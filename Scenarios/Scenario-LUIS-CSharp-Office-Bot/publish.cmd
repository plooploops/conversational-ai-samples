nuget restore
msbuild CoreBot.sln -p:DeployOnBuild=true -p:PublishProfile=bot-Web-Deploy.pubxml -p:Password=botpassword

