
----------- setup
git config --global user.name "IT Automator"
git config --global user.email "github@itautomator.com"
cd "C:\Users\JasonSimotas\My Local Files\GitHub"

----------- clone
git clone https://github.com/ITAutomator/IntuneApp.git

----------- pull
cd "C:\Users\JasonSimotas\My Local Files\GitHub\IntuneApp"
git pull

----------- push
git add .
git commit -m "Update to readme"
git push

----------- autosync
# Change directory to your repository folder
cd "C:\Users\JasonSimotas\My Local Files\GitHub\IntuneApp"

# Pull the latest changes
git pull

# Add all changes, commit, and push
git add .
git commit -m "Automated sync"
git push



