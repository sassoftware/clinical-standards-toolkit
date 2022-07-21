# How to Contribute

We'd love to accept your patches and contributions to this project. There are just a few guidelines you need to follow.

## Contributor License Agreement

Contributions to this project must be accompanied by a signed [Contributor Agreement](ContributorAgreement.txt).  You (or your employer) retain the copyright to your contribution, this simply gives us permission to use and redistribute your contributions as part of the project.

## Code reviews

All submissions, including submissions by project members, require review. We use GitHub pull requests for this purpose. Consult [GitHub Help](https://help.github.com/articles/about-pull-requests/) for more information on using pull requests.

## Request New Standards or Features

Don't have the resources to contribute?  Feel free to run it by us!  Just open an issue in GitHub and we will evaluate your request.  If it's something we can do, we will likely need your help with use cases and sample programs.  

## Development
SAS Clinical Standards toolkit is a bit unusual in that it is deployed to separate locations on your server where all work and modifications occur.  Development or enhancement occurs in your cstGlobalLibrary\cstSampleLibrary.  Once it's all working and ready to be contributed, it must be copied into your GIT local repository and undergo some cleanup in preparation for deployments. 

**Before proceeding, make sure that source code complies with the open source license and all sample data used is de-identified or preferrably completely made up.**

### Submitting a Pull Request
Submitting a pull request uses the standard process at GitHub. Note that in the submitted changes, there must always be a sample programs that specifically demonstrate using the standard being contributed or corrected.  Pull requests that do not have samples will not be accepted.

You also must include the text from the ContributerAgreement.txt file along with your sign-off verifying that the change originated from you.

### Adding A New Standard to GitHub
1.  Ensure that you are working in the pull request branch.
2.  Create a new module in the GIT Repository by copying the module-template from the templates folder to the standards folder and change it to an appropriate name following the convention used for other standards.
3.  Copy the content of the cstGlobalLibrary folder to the source/standards folder.
4.  Copy the content of the cstSampleLibrary folder to the source/sample folder.
5.  If the new standard is XML, copy the schema-repository and xsl-repository in a similar manner.  Otherwise, these folders can be deleted.
6.  Edit the module.properties file and update the properties accordingly.
7.  The build.xml file does NOT require changes.  It is built to address any type of component as long as it follows the conventions used by all standards.  When in doubt, simply review an existing similar standard.
8.  Run `ant info` and review all the properties to ensure they are correct (note: most of these are the same values as used for deployment and should be the same)
9.  Run `ant create-cport-files`.  This will examine all folders in your standard, create transport files for SAS data files, and remove the SAS data files.  This step allows your standard to be deployed across platforms.
10. Test the distribution by running `ant dist`.  This will copy the contents to the dist folder in the repository and recreate all the SAS data files for the platform.  Verify it was copied correctly and folders containing SAS data files are expanded back to the actual SAS data files.
11. Prior to running the next steps, make a backup copy of the standard in cstGlobalLibrary and cstSampleLibrary and unregister the standard.
12. Test the deployment by running `ant deploy`.  This will recreate the standard in the cstGlobalLibrary and cstSampleLibrary and register it.
13. Run your sample programs to verify that the standard was deployed correctly and is working.
14. If everything works correctly, you can now contribute your new standard.

### Updating an Existing Standard
1.  Ensure that you are working in the pull request branch.
2.  Copy any file changes and/or additions from the cstGlobalLibrary folder to the appropriate folder in source/standards.
3.  Copy any file changes and/or additions from the cstSampleLibrary folder to the appropriate folder in source/sample.
4.  SAS data files only need to be copied if you changed the content.  If this is the case, you must copy ALL data files in the same folder, even if they were not changed.  Results datasets in the sample\results folder should never be added to GitHub.
5.  Run `ant info` and review all the properties to ensure they are correct (note: most of these are the same values as used for deployment and should be the same)
9.  If SAS data files were updated, run `ant create-cport-files`.  This will examine all folders in your standard, create transport files for SAS data files, and remove the SAS data files.
10. You are now ready to contribute your changes.

### Requirements for Contributions
* You must include a sample implementation and a reasonable amount of samples to demonstrate the use of the new standard.
* If you modify existing standards or macros, you must also add one or more program to the sample standard library that demonstrates the change so that the contribution can be verified.

### Tips
* The samples library contains all the samples that originally shipped with SAS Clinical Standards Toolki 1.7.2.  You should be able to repurpose these for any standards that you add.
* When in doubt about folder structures, take a look at a similiar existing standard.
