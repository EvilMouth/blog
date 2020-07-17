cd public
git init
git config user.name "CI"
git config user.email "ci@zyhang.com"
git remote add secure-origin git@github.com:izyhang/myblog.git
git checkout -b gh-pages
git add .
git commit -m "Updated docs"
git push --force secure-origin gh-pages