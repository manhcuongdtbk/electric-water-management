# Changelog

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
