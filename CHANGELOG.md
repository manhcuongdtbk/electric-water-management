# Changelog

## [1.1.1](https://github.com/manhcuongdtbk/electric-water-management/compare/v1.1.0...v1.1.1) (2026-06-11)


### Code Refactoring

* use :unprocessable_content for HTTP 422 (Rack deprecation) ([#291](https://github.com/manhcuongdtbk/electric-water-management/issues/291)) ([5bdf72b](https://github.com/manhcuongdtbk/electric-water-management/commit/5bdf72b525469d0a3c6b8774f6dbd70563ca7643))


### Documentation

* centralize terminology and add lightweight document governance (ADR-023) ([1842dcb](https://github.com/manhcuongdtbk/electric-water-management/commit/1842dcbcd3391ed9cfcfa0bc775a7757acedb60d))
* **contributing:** document PR merge methods to keep changelog clean ([#286](https://github.com/manhcuongdtbk/electric-water-management/issues/286)) ([d6c62d6](https://github.com/manhcuongdtbk/electric-water-management/commit/d6c62d6e8705caeed8478f447c188d7f91186da7))
* **ops:** fix environment + backup drift in ops guides (phase 2) ([#311](https://github.com/manhcuongdtbk/electric-water-management/issues/311)) ([73718f2](https://github.com/manhcuongdtbk/electric-water-management/commit/73718f246789a75b71af55a5b020f381c00eee95))
* **release:** document release-please setup gotchas from 1.1.0 ([#287](https://github.com/manhcuongdtbk/electric-water-management/issues/287)) ([513c824](https://github.com/manhcuongdtbk/electric-water-management/commit/513c824cde46fbf3966abe279fba1525b8ea583c))
* **release:** record P4 Railway environments setup (ADR-005) ([#292](https://github.com/manhcuongdtbk/electric-water-management/issues/292)) ([4e69569](https://github.com/manhcuongdtbk/electric-water-management/commit/4e69569cf62e4df4bd1f45e2b19ab0e6145247b7))
* **sdlc:** add onboarding guide and fix canonical-doc drift (phase 1) ([#308](https://github.com/manhcuongdtbk/electric-water-management/issues/308)) ([62e8334](https://github.com/manhcuongdtbk/electric-water-management/commit/62e83344a0b0a85010f9ad8d12ae163594bb9f5a))
* **sdlc:** add traceability & change-management process (ADR-013..015) ([#293](https://github.com/manhcuongdtbk/electric-water-management/issues/293)) ([8a3f57a](https://github.com/manhcuongdtbk/electric-water-management/commit/8a3f57a1dae0e463c5ae9fc8611c0a429e70a79c))
* **sdlc:** give each optional improvement a revisit trigger ([#304](https://github.com/manhcuongdtbk/electric-water-management/issues/304)) ([b5c387b](https://github.com/manhcuongdtbk/electric-water-management/commit/b5c387b45d27653402b3ff7887c71763bc1a944a))
* **sdlc:** intake & prioritization process (Backlog [#4](https://github.com/manhcuongdtbk/electric-water-management/issues/4), ADR-019..020) ([#303](https://github.com/manhcuongdtbk/electric-water-management/issues/303)) ([42d1a40](https://github.com/manhcuongdtbk/electric-water-management/commit/42d1a40186cd547f2642c9b2c4673c338d3d62e4))
* **sdlc:** operations & maintenance process (Backlog [#3](https://github.com/manhcuongdtbk/electric-water-management/issues/3), ADR-016..018) ([#294](https://github.com/manhcuongdtbk/electric-water-management/issues/294)) ([6d4ae61](https://github.com/manhcuongdtbk/electric-water-management/commit/6d4ae61a871f86c5355aab146be06b65ba8aaea4))


### Continuous Integration

* add Dependabot config for bundler, docker, and github-actions ([#296](https://github.com/manhcuongdtbk/electric-water-management/issues/296)) ([4c68dba](https://github.com/manhcuongdtbk/electric-water-management/commit/4c68dba020827c6e2a8c55be439ed8cd2cb02af2))
* add team-wide Claude Code hooks (CI monitor + pre-push base guard) ([#295](https://github.com/manhcuongdtbk/electric-water-management/issues/295)) ([258ac43](https://github.com/manhcuongdtbk/electric-water-management/commit/258ac436d78700a7f137b53b0489ec324f263ee3))
* bump actions to Node 24-compatible versions ([#289](https://github.com/manhcuongdtbk/electric-water-management/issues/289)) ([4ebbe15](https://github.com/manhcuongdtbk/electric-water-management/commit/4ebbe1595084a1f6f96deebc2f31e7b94c835abd))
* bump release-please-action to Node 24-compatible v5 ([be594ad](https://github.com/manhcuongdtbk/electric-water-management/commit/be594ad73a1d97bcfd00c31d122a555642991c1d))
* bump release-please-action to Node 24-compatible v5 ([fd28700](https://github.com/manhcuongdtbk/electric-water-management/commit/fd287006059f844b1883e28fac5f65526fd27583))
* gate heavy jobs on code changes, drop edited trigger (ADR-021) ([#305](https://github.com/manhcuongdtbk/electric-water-management/issues/305)) ([7193db2](https://github.com/manhcuongdtbk/electric-water-management/commit/7193db25a14ebae77bb3b764df40a0b5e7a48725))
* ignore all merge commits in commitlint ([#302](https://github.com/manhcuongdtbk/electric-water-management/issues/302)) ([61ac252](https://github.com/manhcuongdtbk/electric-water-management/commit/61ac2526be65cacce4fc0de01c6e004de38058b0))
* ignore Dependabot commits in commitlint (subject-case) ([#306](https://github.com/manhcuongdtbk/electric-water-management/issues/306)) ([240c709](https://github.com/manhcuongdtbk/electric-water-management/commit/240c709372eed585535cf96622e07f68cff95a49))
* machine-enforce document governance (links, map, glossary) — ADR-024 ([8a5f315](https://github.com/manhcuongdtbk/electric-water-management/commit/8a5f3159147bcfda208007a4fa754edd184d0af6))
* run tests (rspec, system specs, schema drift, zeitwerk) on pull requests ([#288](https://github.com/manhcuongdtbk/electric-water-management/issues/288)) ([3415798](https://github.com/manhcuongdtbk/electric-water-management/commit/3415798c063af08bf2db72cb23a4f805eed88b03))


### Miscellaneous Chores

* **deps-dev:** Bump rspec-rails from 7.1.1 to 8.0.4 ([#301](https://github.com/manhcuongdtbk/electric-water-management/issues/301)) ([9986d8e](https://github.com/manhcuongdtbk/electric-water-management/commit/9986d8e0ca0ab2f8aed5f31ce126c51333c14008))
* **deps-dev:** Bump shoulda-matchers from 6.5.0 to 7.0.1 ([#298](https://github.com/manhcuongdtbk/electric-water-management/issues/298)) ([dcfa124](https://github.com/manhcuongdtbk/electric-water-management/commit/dcfa124adefd36a389e804b39329fa98f58e27bb))
* **deps:** Bump the ruby-minor-patch group across 1 directory with 2 updates ([#297](https://github.com/manhcuongdtbk/electric-water-management/issues/297)) ([27d0555](https://github.com/manhcuongdtbk/electric-water-management/commit/27d05556e975216ab301c406f519b001b5676903))
* merge-back release 1.1.0 into develop ([6af97a1](https://github.com/manhcuongdtbk/electric-water-management/commit/6af97a1ea56d33bfcfda6fd57a3ea4fa4a3e4136))

## [1.1.0](https://github.com/manhcuongdtbk/electric-water-management/compare/v1.0.1...v1.1.0) (2026-06-07)


### Features

* application self-version reporting ([7198cb7](https://github.com/manhcuongdtbk/electric-water-management/commit/7198cb765d810b21fe11d80e4532c1d720146403))
* **version:** add public /version JSON endpoint ([90b7656](https://github.com/manhcuongdtbk/electric-water-management/commit/90b7656895cbb6bcb10f754c8ba0169eda1bd001))
* **version:** read app version into a constant and SystemInfo module ([c57f282](https://github.com/manhcuongdtbk/electric-water-management/commit/c57f282cf62d96bbdfd852c26b442da24fdcca71))
* **version:** show version and environment at the sidebar bottom ([8fab102](https://github.com/manhcuongdtbk/electric-water-management/commit/8fab102fd0d4a5daea4294766799278e8e6275cc))
* **version:** show version and environment on the login screen ([9a95b16](https://github.com/manhcuongdtbk/electric-water-management/commit/9a95b16a42b3be604a2053df190f9c051eedf15f))
* **version:** stamp version and environment into Excel export footer ([98fec94](https://github.com/manhcuongdtbk/electric-water-management/commit/98fec94cb2e28e5bd4cca665f616f8e1d95d4bed))
* **version:** tag production logs with version and environment ([b136728](https://github.com/manhcuongdtbk/electric-water-management/commit/b136728d68aba69cc8619f85498b4d3b4c68bbe7))


### Bug Fixes

* **users:** block role escalation to technician in update ([bb805f9](https://github.com/manhcuongdtbk/electric-water-management/commit/bb805f9124c1b54e2ea730fc16fd1dda6b7ed617))


### Dependencies

* **deps:** bump puma to &gt;= 8.0.2 to fix CVE-2026-47736/47737 ([ec6f53a](https://github.com/manhcuongdtbk/electric-water-management/commit/ec6f53a57a3c87631198c7d083c35ea1a5c5e9a1))
* strip AGENTS.md and CONTRIBUTING.md from delivery build ([0ad82c3](https://github.com/manhcuongdtbk/electric-water-management/commit/0ad82c3f42e46cd02fafef26d1eca72ef669273d))
* strip internal docs/superpowers from delivery build ([ddc7fad](https://github.com/manhcuongdtbk/electric-water-management/commit/ddc7fad5c3f0a5c27da1b30e0db846975eb4cea3))


### Code Refactoring

* **version:** localize Excel footer label via i18n ([74a190a](https://github.com/manhcuongdtbk/electric-water-management/commit/74a190ab5957ba928b79ac720c1f37377230848a))
* **version:** make SystemInfo own the version and drop app-name coupling ([1ecb6cf](https://github.com/manhcuongdtbk/electric-water-management/commit/1ecb6cf048ab77e6a8c71f8a8cd3c1fed45aff54))
* **version:** rename environment label to app_environment ([0b56755](https://github.com/manhcuongdtbk/electric-water-management/commit/0b56755731dcb70c56fefc9f2f8b2793eb59cbb5))
* **version:** show version and environment on one sidebar line ([20b1cea](https://github.com/manhcuongdtbk/electric-water-management/commit/20b1ceae9850564099c329f7b169e85533cd0c9a))
* **version:** spell out environment identifiers (no abbreviations) ([dac488c](https://github.com/manhcuongdtbk/electric-water-management/commit/dac488c5e18a22b41aa0971c052f1ad2db321921))


### Documentation

* clarify Excel label and sync implementation plan ([8b17d08](https://github.com/manhcuongdtbk/electric-water-management/commit/8b17d08486064a9973beaa150600b1eec59d8a6d))
* **contributing:** mark static CI live after P2 ([de0d822](https://github.com/manhcuongdtbk/electric-water-management/commit/de0d8222f26ece0e3feb2d365f9ac14136e7e20f))
* **contributing:** note release-please configured after P3 ([3484c02](https://github.com/manhcuongdtbk/electric-water-management/commit/3484c0203e30c36be936c4de2dffa48386c11c1c))
* define app environment vs Rails environment glossary ([edbd1c8](https://github.com/manhcuongdtbk/electric-water-management/commit/edbd1c8a60b56c6e088c2d4be3f09f212ce22f2f))
* **docker:** add changelog entry for KIEN_THUC_DOCKER 1.8.1 ([94fd0ca](https://github.com/manhcuongdtbk/electric-water-management/commit/94fd0cacc082741eee4df459dbe807474f08f7ff))
* **docker:** note AGENTS.md and CONTRIBUTING.md as stripped dev files ([33ca57e](https://github.com/manhcuongdtbk/electric-water-management/commit/33ca57e17151238c893f5f0ee92aebc3967d7a6a))
* **plan:** add application self-version reporting implementation plan ([4bc6b02](https://github.com/manhcuongdtbk/electric-water-management/commit/4bc6b024237b3bf53966343a7d2968f869fadcef))
* point README docs table to canonical AGENTS.md ([383b8a5](https://github.com/manhcuongdtbk/electric-water-management/commit/383b8a505393fe59298598ae3481619a019e8f1a))
* **sdlc:** add CONTRIBUTING guide for human workflow ([5e18e36](https://github.com/manhcuongdtbk/electric-water-management/commit/5e18e360988155a81dda40f35b88c513ed599361))
* **sdlc:** add P1 implementation plan (documentation foundation) ([66198e8](https://github.com/manhcuongdtbk/electric-water-management/commit/66198e802ee7fa8510b6650258c52f86f906c4b1))
* **sdlc:** add P2 implementation plan (Git Flow + minimal static CI) ([b9d1ce6](https://github.com/manhcuongdtbk/electric-water-management/commit/b9d1ce65b620d44bf77fb410357ec564f689cdbf))
* **sdlc:** add P3 implementation plan (release-please) ([5a630d8](https://github.com/manhcuongdtbk/electric-water-management/commit/5a630d81b95393157c37c433e09c450f4db3fb9f))
* **sdlc:** fix setup-ruby input in P2 plan (ruby-version, not ruby-version-file) ([72944de](https://github.com/manhcuongdtbk/electric-water-management/commit/72944dee29bc5013ab0d48676e3ecd3f694aca0e))
* **sdlc:** make AGENTS.md the canonical conventions source ([7c73391](https://github.com/manhcuongdtbk/electric-water-management/commit/7c73391e62417d1c43596757e5cb51e494057077))
* **sdlc:** P1 — documentation & conventions foundation (canonical AGENTS.md) ([0800606](https://github.com/manhcuongdtbk/electric-water-management/commit/08006069ab40e7a5d4624e8d248448c48bfdaa71))
* **sdlc:** record documentation versioning policy in ADR-002 ([e33be42](https://github.com/manhcuongdtbk/electric-water-management/commit/e33be4263113bc0599c9334c4a2a8e030e6c60da))
* **sdlc:** record P2 static-CI boundary in release spec ([0d0a71f](https://github.com/manhcuongdtbk/electric-water-management/commit/0d0a71fbb5acbf2c35fc98402691698a36399891))
* **sdlc:** record P3 release-please rollout in release spec ([e80c006](https://github.com/manhcuongdtbk/electric-water-management/commit/e80c006a592548a0b4395f4a46279f0eef8461c1))
* **spec:** add application self-version reporting design ([bd69847](https://github.com/manhcuongdtbk/electric-water-management/commit/bd69847b405e17d940fa871e2f0cec4eb1acf3e3))
* **spec:** move SystemInfo to lib and compact sidebar version display ([0378f77](https://github.com/manhcuongdtbk/electric-water-management/commit/0378f772dc53853151499f563f55c393db6c5940))
* **spec:** record one-line sidebar and i18n footer decisions ([f0eeb25](https://github.com/manhcuongdtbk/electric-water-management/commit/f0eeb2519a0c9a25496319dae00853afcf976aaa))
* **spec:** record SystemInfo version ownership and def self. (v0.5.0) ([302eb91](https://github.com/manhcuongdtbk/electric-water-management/commit/302eb91a5da82df2f83acc5a009caaa2575bacfe))
* **spec:** refine version-reporting design after owner review ([a0d574f](https://github.com/manhcuongdtbk/electric-water-management/commit/a0d574fc1304cf5603b26d565ef998b83636d915))
* spell out environment identifiers in glossary and spec ([ab1376f](https://github.com/manhcuongdtbk/electric-water-management/commit/ab1376fa31163a3163d101555cecbb29a53e6ea2))


### Tests

* **users:** cover system_admin cannot create technician account ([f59e41a](https://github.com/manhcuongdtbk/electric-water-management/commit/f59e41a0bbde018c305951598a7fc320640e4ba7))


### Continuous Integration

* add commitlint config for Conventional Commits ([c294284](https://github.com/manhcuongdtbk/electric-water-management/commit/c2942847a6e5f8b67265d5aa2c342d7c76d9b81b))
* add minimal static CI workflow on pull requests ([f6cdc63](https://github.com/manhcuongdtbk/electric-water-management/commit/f6cdc63c5a3bbb5990a6ae59dcd6936e395fcffa))
* add native branch-source guard script ([095ad0a](https://github.com/manhcuongdtbk/electric-water-management/commit/095ad0a09cbb0c348961db8135587c69afde3b90))
* add release-please config, manifest, and version.txt ([8c24291](https://github.com/manhcuongdtbk/electric-water-management/commit/8c24291d8f5fc6f56feff77c65a7cca5ebd9bae6))
* add release-please workflow for final releases on main ([7afff63](https://github.com/manhcuongdtbk/electric-water-management/commit/7afff6386427d2d34c050fba2a726be88fd116e0))
* allow release-please-- branches as a valid main source in guard ([954fdae](https://github.com/manhcuongdtbk/electric-water-management/commit/954fdae682a6f1ab8b29aa5ea029df02f8f0f095))
* bootstrap Git Flow develop branch and minimal static CI (P2) ([0c7326f](https://github.com/manhcuongdtbk/electric-water-management/commit/0c7326fbb0b68177e9b4fb45ba83afc2ec55a882))
* configure release-please for final releases on main (P3) ([8fbbeb0](https://github.com/manhcuongdtbk/electric-water-management/commit/8fbbeb0343a302a4a1d4e2a4cf76c5399025b5f6))
* run bundler-audit via project binstub to honor ignore config ([e1598c5](https://github.com/manhcuongdtbk/electric-water-management/commit/e1598c5421c780fd5c8bd08daf30b3eb2ef0e606))
* show all commit types in release-please changelog ([5751a4b](https://github.com/manhcuongdtbk/electric-water-management/commit/5751a4b1a83b7599ca50c292c01f38f2be369f9a))
* use English in CI workflow and track latest Node LTS ([216529e](https://github.com/manhcuongdtbk/electric-water-management/commit/216529e1116b9613f3567ee5a5d6dc772b2b6924))
* use English messages in branch-source guard ([0f1b216](https://github.com/manhcuongdtbk/electric-water-management/commit/0f1b216985683e6244a06669f3190707c63595ff))
* use non-component-prefixed tags for release-please ([a37ab88](https://github.com/manhcuongdtbk/electric-water-management/commit/a37ab88d3a166871403eb9150b07aa8e6d6b1e7e))


### Miscellaneous Chores

* **brakeman:** grandfather existing warnings via config/brakeman.ignore ([9e1e6f3](https://github.com/manhcuongdtbk/electric-water-management/commit/9e1e6f3b481a7e69aa634ec8900ff678c39dc83f))
* **bundler-audit:** document ignored advisories for CI baseline ([2abe358](https://github.com/manhcuongdtbk/electric-water-management/commit/2abe358620b78f5e3d79600a036396c63da37bee))
* **rubocop:** grandfather existing offenses via .rubocop_todo.yml ([e8d1c31](https://github.com/manhcuongdtbk/electric-water-management/commit/e8d1c3170e8ebda52da341203a4721a125d84ef5))
