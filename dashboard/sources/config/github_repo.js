const repo = (process.env.GITHUB_REPO || '').trim();

const data = [{ github_repo: repo.length > 0 ? repo : null }];

export { data };
