# Automation in Azure #

After running this template you need to add a Azure Automation run as account. Additionally you need to start the DSC configuration compilation.

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fpeterschen%2Fblog%2Fmaster%2Fsamples%2Fautomation-in-azure%2Fazuredeploy.json)

# Configure Azure Automation run as account #

Navigate to **Automation Accounts > *[your account]* > Run as accounts**:

![Configure Azure Automation run as account step 1](automation-in-azure/runas1.png?raw=true)

Select **Azure Run As Account**:

![Configure Azure Automation run as account step 2](automation-in-azure/runas2.png?raw=true)

Hit **Create**:

![Configure Azure Automation run as account step 3](automation-in-azure/runas3.png?raw=true)

# Compile DSC configuration #

Navigate to **Automation Accounts > *[your account]* > State configurations (DSC)**:

![Compile DSC configuration step 1](automation-in-azure/dsc1.png?raw=true)

Select **Configurations** and select **Dsc**:

![Compile DSC configuration step 2](automation-in-azure/dsc2.png?raw=true)

Hit **Compile**:

![Compile DSC configuration step 3](automation-in-azure/dsc3.png?raw=true)