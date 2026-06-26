# Changelog

## [1.2.2](https://github.com/manhcuongdtbk/electric-water-management/compare/v1.2.1...v1.2.2) (2026-06-26)


### Bug Fixes

* **ci:** add 'release' to commitlint type-enum ([1c52eee](https://github.com/manhcuongdtbk/electric-water-management/commit/1c52eeead5f1ec8ddd855ac515d58a4e81b5dc3a)), closes [#475](https://github.com/manhcuongdtbk/electric-water-management/issues/475)

## [1.2.1](https://github.com/manhcuongdtbk/electric-water-management/compare/v1.2.0...v1.2.1) (2026-06-26)


### Bug Fixes

* **ci:** exempt dependabot from issue-link guardrail ([#449](https://github.com/manhcuongdtbk/electric-water-management/issues/449)) ([891a2c8](https://github.com/manhcuongdtbk/electric-water-management/commit/891a2c83cbdf3708d7a08b34816256f1f9abd283))
* **ci:** handle both bot author formats in issue-link guardrail ([#453](https://github.com/manhcuongdtbk/electric-water-management/issues/453)) ([e309053](https://github.com/manhcuongdtbk/electric-water-management/commit/e3090533978f831e8b693c809902127c0d278a82))
* **ci:** read allowed abbreviations from THUAT_NGU.md to avoid commitlint false positives ([2e2e7a3](https://github.com/manhcuongdtbk/electric-water-management/commit/2e2e7a35cc4b7182ebce3666ee8ec1666c03ad71)), closes [#475](https://github.com/manhcuongdtbk/electric-water-management/issues/475)
* **demo:** fix DC demo page order and narration, add page order to CONTRIBUTING ([#451](https://github.com/manhcuongdtbk/electric-water-management/issues/451)) ([a3212af](https://github.com/manhcuongdtbk/electric-water-management/commit/a3212af238b230e29159e6ea4865c1dbf0a48962))
* **pump:** remove public CP from pump allocation recipient dropdown ([#459](https://github.com/manhcuongdtbk/electric-water-management/issues/459)) ([#461](https://github.com/manhcuongdtbk/electric-water-management/issues/461)) ([2d99fcc](https://github.com/manhcuongdtbk/electric-water-management/commit/2d99fccae6c2de33535cc4085c1d6af092566612))


### Documentation

* add spec for doc-code sync guardrails (ADR-062..064) ([#464](https://github.com/manhcuongdtbk/electric-water-management/issues/464)) ([#465](https://github.com/manhcuongdtbk/electric-water-management/issues/465)) ([8203d0a](https://github.com/manhcuongdtbk/electric-water-management/commit/8203d0ae670dd6ac73afb6ce98f5f424a9c89915))
* ADR-061 retrospective for division_commander + footnote 7 specs ([#462](https://github.com/manhcuongdtbk/electric-water-management/issues/462)) ([#463](https://github.com/manhcuongdtbk/electric-water-management/issues/463)) ([f47a78c](https://github.com/manhcuongdtbk/electric-water-management/commit/f47a78cb4b7037e8bb5a10961f1c59166a9709ba))
* audit cross-file fact duplication and add canonical pointers ([#432](https://github.com/manhcuongdtbk/electric-water-management/issues/432)) ([#471](https://github.com/manhcuongdtbk/electric-water-management/issues/471)) ([286584d](https://github.com/manhcuongdtbk/electric-water-management/commit/286584d9c5b0a4455da130eb46e0f5e16c630c62))
* consolidate supplementary spec files into canonical with release traceability ([#439](https://github.com/manhcuongdtbk/electric-water-management/issues/439)) ([07dff16](https://github.com/manhcuongdtbk/electric-water-management/commit/07dff16a410a303c608be4d7ddb5ecbfb8128f78))
* **docker:** add coverage subcommand and update seeds.rb output ([#447](https://github.com/manhcuongdtbk/electric-water-management/issues/447)) ([87a38cb](https://github.com/manhcuongdtbk/electric-water-management/commit/87a38cb30f79ba55f9434b6c41ed192bb8976d3d))
* document Vietnamese release notes process in CONTRIBUTING.md ([#444](https://github.com/manhcuongdtbk/electric-water-management/issues/444)) ([e1e8997](https://github.com/manhcuongdtbk/electric-water-management/commit/e1e89972f56c4e44ce25995966ec3c900b8fbe08))
* fix 2 drifts in V2_THIET_KE introduced by audit session ([#464](https://github.com/manhcuongdtbk/electric-water-management/issues/464)) ([#466](https://github.com/manhcuongdtbk/electric-water-management/issues/466)) ([1dff297](https://github.com/manhcuongdtbk/electric-water-management/commit/1dff2977e3f58d7383bd8e868af10644d1db5cda))
* reconcile 3 code-vs-spec gaps — manual_usage, billing display, history range ([#457](https://github.com/manhcuongdtbk/electric-water-management/issues/457)) ([#460](https://github.com/manhcuongdtbk/electric-water-management/issues/460)) ([366d4b4](https://github.com/manhcuongdtbk/electric-water-management/commit/366d4b41e7c0355bfe29fac6d80cc6f034a37d8c))
* sync 5 canonical docs with codebase — 9 stale facts ([#456](https://github.com/manhcuongdtbk/electric-water-management/issues/456)) ([#458](https://github.com/manhcuongdtbk/electric-water-management/issues/458)) ([41838d9](https://github.com/manhcuongdtbk/electric-water-management/commit/41838d974436f822b98b5b08e14bbd10e86913d4))


### Continuous Integration

* auto-prepend Vietnamese release notes template (ADR-066, [#446](https://github.com/manhcuongdtbk/electric-water-management/issues/446)) ([#469](https://github.com/manhcuongdtbk/electric-water-management/issues/469)) ([4220a08](https://github.com/manhcuongdtbk/electric-water-management/commit/4220a085174a4374b790779be5bd0509bcff62b3))
* auto-remind merge-back to develop after release/hotfix merges to main ([#452](https://github.com/manhcuongdtbk/electric-water-management/issues/452)) ([a6e3b30](https://github.com/manhcuongdtbk/electric-water-management/commit/a6e3b3046125416f0a76fde6b736b54b4d5608d0))
* auto-sync milestone name with tag version on release ([#455](https://github.com/manhcuongdtbk/electric-water-management/issues/455)) ([#470](https://github.com/manhcuongdtbk/electric-water-management/issues/470)) ([9b33e0a](https://github.com/manhcuongdtbk/electric-water-management/commit/9b33e0afeb6f7578d07300d6c5d46b3abf8aefad))
* auto-upload demo-bundle to GitHub Release assets after tag ([#454](https://github.com/manhcuongdtbk/electric-water-management/issues/454)) ([66a2e59](https://github.com/manhcuongdtbk/electric-water-management/commit/66a2e595229b103e13e7d3281a953eebd3513953))
* implement doc-code sync guardrails (ADR-062/063, [#464](https://github.com/manhcuongdtbk/electric-water-management/issues/464)) ([#467](https://github.com/manhcuongdtbk/electric-water-management/issues/467)) ([52d5526](https://github.com/manhcuongdtbk/electric-water-management/commit/52d5526bb0a282ea692802f001f5c212c65ebfcf))
* implement NV traceability guardrail (ADR-065, [#441](https://github.com/manhcuongdtbk/electric-water-management/issues/441)) ([#468](https://github.com/manhcuongdtbk/electric-water-management/issues/468)) ([194e2ad](https://github.com/manhcuongdtbk/electric-water-management/commit/194e2ad7ce2dfd2eb0ee489f066c3ed70ff41083))
* require every PR to reference a GitHub issue (ADR-015 revisit) ([#443](https://github.com/manhcuongdtbk/electric-water-management/issues/443)) ([1fb8ef2](https://github.com/manhcuongdtbk/electric-water-management/commit/1fb8ef2f98d3249f3318ed012ae0c14b3e89d653))


### Miscellaneous Chores

* add no-fact-duplication reminder to PR checklist + fix role count ([#450](https://github.com/manhcuongdtbk/electric-water-management/issues/450)) ([9c1aad9](https://github.com/manhcuongdtbk/electric-water-management/commit/9c1aad9017d129c938947c5bf4fb952536fe0ad0))
* **deps:** Bump the ruby-minor-patch group with 3 updates ([#431](https://github.com/manhcuongdtbk/electric-water-management/issues/431)) ([eafa520](https://github.com/manhcuongdtbk/electric-water-management/commit/eafa5207719ce5b10f67c1c5be2bb1ba0bddfbdd))

## [1.2.0](https://github.com/manhcuongdtbk/electric-water-management/compare/v1.1.1...v1.2.0) (2026-06-22)


### Features

* add ADR status lifecycle + guardrail (ADR-033) ([#340](https://github.com/manhcuongdtbk/electric-water-management/issues/340)) ([83912b2](https://github.com/manhcuongdtbk/electric-water-management/commit/83912b2897e55b99cb7c75ae6559d392d760de11))
* AGENTS-compliance review dimension (ADR-031) ([#336](https://github.com/manhcuongdtbk/electric-water-management/issues/336)) ([d3c5116](https://github.com/manhcuongdtbk/electric-water-management/commit/d3c5116d4c8f77bd7606cc73ea81eef8b2d13978))
* **billing:** hiển thị chi tiết tổn hao (TN3, milestone 1.2.0) ([#331](https://github.com/manhcuongdtbk/electric-water-management/issues/331)) ([f46b342](https://github.com/manhcuongdtbk/electric-water-management/commit/f46b34278e921e93825c9940297074fc0440469f))
* **billing:** per-type loss/usage reconciliation table ([#332](https://github.com/manhcuongdtbk/electric-water-management/issues/332)) ([#364](https://github.com/manhcuongdtbk/electric-water-management/issues/364)) ([d3c44dc](https://github.com/manhcuongdtbk/electric-water-management/commit/d3c44dcd3da5133fa2907b13584204e2079bed9b))
* **ci:** test-dimension traceability guardrail (ADR-030) ([#335](https://github.com/manhcuongdtbk/electric-water-management/issues/335)) ([e1bd555](https://github.com/manhcuongdtbk/electric-water-management/commit/e1bd555e07dbcc49053f33ec1ae76e3fa59b46eb)), closes [#329](https://github.com/manhcuongdtbk/electric-water-management/issues/329)
* cột "Khác" dạng hệ số (đơn vị) ([#327](https://github.com/manhcuongdtbk/electric-water-management/issues/327)) ([5a76941](https://github.com/manhcuongdtbk/electric-water-management/commit/5a76941ba8bb817619f1ad1ea5477cfbaad4d2bb))
* i18n view guardrail (ADR-032) ([#337](https://github.com/manhcuongdtbk/electric-water-management/issues/337)) ([e4e8f13](https://github.com/manhcuongdtbk/electric-water-management/commit/e4e8f1319b8a540156fe09fbbbe84a3c70ff13ae))
* implement 7 UI/UX improvements for billing, unit config, and meter entries ([#406](https://github.com/manhcuongdtbk/electric-water-management/issues/406)) ([401086b](https://github.com/manhcuongdtbk/electric-water-management/commit/401086b54592262f96bc37f169c626cdca8e8e8b))
* per-zone derived-data freshness indicator and Excel export guard ([#334](https://github.com/manhcuongdtbk/electric-water-management/issues/334)) ([9c8d785](https://github.com/manhcuongdtbk/electric-water-management/commit/9c8d78591e6032194cbd1aed460698d9773e47f2))
* **pump:** allocate pump-water electricity per pump station (TN2) ([#396](https://github.com/manhcuongdtbk/electric-water-management/issues/396)) ([1f52212](https://github.com/manhcuongdtbk/electric-water-management/commit/1f522125c3074ba7cb12b394d8a2ac6bec01d0e6))
* **role:** add division commander role (read-only system-wide) ([#419](https://github.com/manhcuongdtbk/electric-water-management/issues/419)) ([79a420a](https://github.com/manhcuongdtbk/electric-water-management/commit/79a420afbb17f9bd708d463eb50cbbece7003e10))


### Bug Fixes

* **hooks:** skip branch-behind guard on branch deletions ([#325](https://github.com/manhcuongdtbk/electric-water-management/issues/325)) ([557f2b0](https://github.com/manhcuongdtbk/electric-water-management/commit/557f2b01f17fe6bb5a836d9d272ca7e3146a658f))
* **i18n:** unify app name to "Hệ thống quản lý điện nước nội bộ" ([#417](https://github.com/manhcuongdtbk/electric-water-management/issues/417)) ([5f728b4](https://github.com/manhcuongdtbk/electric-water-management/commit/5f728b4d84a867b58dbb91a302e94fe4166238dd))
* make zone-direct other-deductions editable independent of manager unit ([#328](https://github.com/manhcuongdtbk/electric-water-management/issues/328)) ([#341](https://github.com/manhcuongdtbk/electric-water-management/issues/341)) ([073886c](https://github.com/manhcuongdtbk/electric-water-management/commit/073886ce51bdc9aa3feb6876805864449e142048))
* **pump:** post-TN2 UX improvements for pump allocation and billing tables ([#415](https://github.com/manhcuongdtbk/electric-water-management/issues/415)) ([7609011](https://github.com/manhcuongdtbk/electric-water-management/commit/76090112e77a4eef66ec55defa260eee55114eb1))
* **traceability:** require whitespace boundary before closing keywords ([#390](https://github.com/manhcuongdtbk/electric-water-management/issues/390)) ([f456435](https://github.com/manhcuongdtbk/electric-water-management/commit/f4564355b264618a20c9e5f611c4b8089e9a447e)), closes [#389](https://github.com/manhcuongdtbk/electric-water-management/issues/389)
* **traceability:** skip pull-request numbers before commenting ([#391](https://github.com/manhcuongdtbk/electric-water-management/issues/391)) ([a01a108](https://github.com/manhcuongdtbk/electric-water-management/commit/a01a108332cb8525f522945fb4204d787f88573d)), closes [#389](https://github.com/manhcuongdtbk/electric-water-management/issues/389)
* **unit_config:** set SA filter dropdowns on validation-error re-render ([#330](https://github.com/manhcuongdtbk/electric-water-management/issues/330)) ([9b8f3aa](https://github.com/manhcuongdtbk/electric-water-management/commit/9b8f3aa613771f2181b63e51436219088f0b3798))


### Documentation

* add "fan-out" to glossary ([#326](https://github.com/manhcuongdtbk/electric-water-management/issues/326)) ([c16815d](https://github.com/manhcuongdtbk/electric-water-management/commit/c16815d07907fc7999b87e244a7a4d5e43477594))
* add ADR-028 pre-build client confirmation gate ([#323](https://github.com/manhcuongdtbk/electric-water-management/issues/323)) ([3cad880](https://github.com/manhcuongdtbk/electric-water-management/commit/3cad880b0066cdff60d459feb70d479942e7c612)), closes [#320](https://github.com/manhcuongdtbk/electric-water-management/issues/320)
* add ADR-029 AI-assisted lifecycle operating model ([#324](https://github.com/manhcuongdtbk/electric-water-management/issues/324)) ([a046ea2](https://github.com/manhcuongdtbk/electric-water-management/commit/a046ea21ebed96cbffce74342421a208caf68b78)), closes [#322](https://github.com/manhcuongdtbk/electric-water-management/issues/322)
* add non-overlap and no-split constraints for per-station pump allocation ([#407](https://github.com/manhcuongdtbk/electric-water-management/issues/407)) ([267196e](https://github.com/manhcuongdtbk/electric-water-management/commit/267196eb00faa0bcb2a02f654d637835f525ce91))
* add supplementary business requirements for client review ([#264](https://github.com/manhcuongdtbk/electric-water-management/issues/264)) ([04177f9](https://github.com/manhcuongdtbk/electric-water-management/commit/04177f97b703378cb534062449a62c4a1dc591b8)), closes [#319](https://github.com/manhcuongdtbk/electric-water-management/issues/319)
* correct [#357](https://github.com/manhcuongdtbk/electric-water-management/issues/357) milestone in demo-dod traceability (1.3.0 -&gt; 1.2.0) ([#387](https://github.com/manhcuongdtbk/electric-water-management/issues/387)) ([7c4df65](https://github.com/manhcuongdtbk/electric-water-management/commit/7c4df65ed60a93d4862c3504188b93b4061ae763))
* design groundwork for milestone 1.2.0 (3 features) ([#321](https://github.com/manhcuongdtbk/electric-water-management/issues/321)) ([3541920](https://github.com/manhcuongdtbk/electric-water-management/commit/354192045d2e9d848e80234137861cd5c4d55010))
* point the code-review hook i18n note at the shipped guardrail ([#338](https://github.com/manhcuongdtbk/electric-water-management/issues/338)) ([f08b002](https://github.com/manhcuongdtbk/electric-water-management/commit/f08b00244a78b4cf0a75bffdc849b1a274c49dc9))
* **sdlc:** sync release-flow descriptions with ADR-005/008/028 ([#350](https://github.com/manhcuongdtbk/electric-water-management/issues/350)) ([07c0c42](https://github.com/manhcuongdtbk/electric-water-management/commit/07c0c427ccfda19ddf669fc493a5ad968a1761a3))
* **spec:** sync [#334](https://github.com/manhcuongdtbk/electric-water-management/issues/334) traceability milestone to 1.2.0 ([a8c74b4](https://github.com/manhcuongdtbk/electric-water-management/commit/a8c74b49e50fac7fff379434259ce9ab89ac6527))
* unify app name across docs and compose.yml ([#421](https://github.com/manhcuongdtbk/electric-water-management/issues/421)) ([187271a](https://github.com/manhcuongdtbk/electric-water-management/commit/187271a8aebedd60f4f68672f15e63280293015c))
* update all docs and screenshots for 1.2.0 release ([#429](https://github.com/manhcuongdtbk/electric-water-management/issues/429)) ([3547c83](https://github.com/manhcuongdtbk/electric-water-management/commit/3547c8392188051b61cac6261705ecd530ec83d1))


### Tests

* add SimpleCov code coverage (line + branch), opt-in via COVERAGE=1 (Refs [#360](https://github.com/manhcuongdtbk/electric-water-management/issues/360)) ([ac6dff4](https://github.com/manhcuongdtbk/electric-water-management/commit/ac6dff441454525d22ce432c473ccf5845a54908))
* audit v1.0.0→v1.1.1 + develop, fix doc bug, harden coverage ([#404](https://github.com/manhcuongdtbk/electric-water-management/issues/404)) ([4b0fe3c](https://github.com/manhcuongdtbk/electric-water-management/commit/4b0fe3c59a2b1f816552a78e89f03426d3705b19))
* **coverage:** add anti-regression ratchet floor (line 96 / branch 80) ([#381](https://github.com/manhcuongdtbk/electric-water-management/issues/381)) ([#385](https://github.com/manhcuongdtbk/electric-water-management/issues/385)) ([2929fab](https://github.com/manhcuongdtbk/electric-water-management/commit/2929fab9a8f7bb17d28e349227af23ff85105e72))
* **coverage:** patch real branch gaps + ratchet branch floor to 81 ([#381](https://github.com/manhcuongdtbk/electric-water-management/issues/381)) ([#388](https://github.com/manhcuongdtbk/electric-water-management/issues/388)) ([667d859](https://github.com/manhcuongdtbk/electric-water-management/commit/667d859bf171a2bdf51a1ee122a8837740b7a231))
* **demo:** bring freshness + loss breakdown demos to ADR-059 standard ([#397](https://github.com/manhcuongdtbk/electric-water-management/issues/397)) ([73e0fd4](https://github.com/manhcuongdtbk/electric-water-management/commit/73e0fd45939e55c28957944c7c1c5f835e841da6))
* enforce 6-role access coverage on every page (role-coverage guardrail) ([#374](https://github.com/manhcuongdtbk/electric-water-management/issues/374)) ([9e4a163](https://github.com/manhcuongdtbk/electric-water-management/commit/9e4a1631cf6f56cde582d929bca1aafd0a7160cf))
* **loss:** cover empty-zone billing display and refresh V2_CHIEU_TEST status ([#333](https://github.com/manhcuongdtbk/electric-water-management/issues/333)) ([d909587](https://github.com/manhcuongdtbk/electric-water-management/commit/d9095875c2a855339613e1e30a0593e73ae9fd9f))
* **mutation:** kill remaining billing-core survivors ([#376](https://github.com/manhcuongdtbk/electric-water-management/issues/376)) ([#378](https://github.com/manhcuongdtbk/electric-water-management/issues/378)) ([58eb307](https://github.com/manhcuongdtbk/electric-water-management/commit/58eb3072b74e382c42cd5927d2f5587da013e846))
* **mutation:** Ripper-based mutation harness for the billing core ([#377](https://github.com/manhcuongdtbk/electric-water-management/issues/377)) ([52678d3](https://github.com/manhcuongdtbk/electric-water-management/commit/52678d3a26dd1cc9e2d62550b24c5bf46cb1e877))
* purge committed leftovers before suite and force RAILS_ENV=test (Refs [#362](https://github.com/manhcuongdtbk/electric-water-management/issues/362)) ([01fd4fc](https://github.com/manhcuongdtbk/electric-water-management/commit/01fd4fc40055937f6bda02fa8821bb72c2c843f1))
* **role-behavior:** machine-enforce per-role behavior coverage ([#373](https://github.com/manhcuongdtbk/electric-water-management/issues/373)) ([#380](https://github.com/manhcuongdtbk/electric-water-management/issues/380)) ([cc8d330](https://github.com/manhcuongdtbk/electric-water-management/commit/cc8d3300291889b1ebff667865238073116139f6))


### Continuous Integration

* automate close-traceability on pull request merge (ADR-035) ([#346](https://github.com/manhcuongdtbk/electric-water-management/issues/346)) ([fc1da4d](https://github.com/manhcuongdtbk/electric-water-management/commit/fc1da4d215a1cecd43c7d606d001fefd0220c078))
* **demo:** add a "demo tốt" quality standard to the DoD (ADR-059) ([#384](https://github.com/manhcuongdtbk/electric-water-management/issues/384)) ([a073d51](https://github.com/manhcuongdtbk/electric-water-management/commit/a073d516fbd929e34c54882b671dc4a6c65de114))
* **demo:** AI-assisted demo drafting habit + g demo:spec scaffold ([#353](https://github.com/manhcuongdtbk/electric-water-management/issues/353)) ([ecb5266](https://github.com/manhcuongdtbk/electric-water-management/commit/ecb5266324afc1a915892768a53dd6a77b6dfc27))
* **demo:** automated demo recording (Playwright) for PR and release review ([#347](https://github.com/manhcuongdtbk/electric-water-management/issues/347)) ([ecd1284](https://github.com/manhcuongdtbk/electric-water-management/commit/ecd128450ed43735e390135d35eb6a18ba8e7e08))
* **demo:** backfill TN1 demo spec; fix recorder NV anchor + caption overlay (Refs [#355](https://github.com/manhcuongdtbk/electric-water-management/issues/355)) ([d21e94e](https://github.com/manhcuongdtbk/electric-water-management/commit/d21e94ea133e9e137694699c74286c52e32588d0))
* **demo:** bundle customer-facing demo delta for release review (Refs [#351](https://github.com/manhcuongdtbk/electric-water-management/issues/351)) ([9474e83](https://github.com/manhcuongdtbk/electric-water-management/commit/9474e836f46806d1506f97ae39080f2ee56351d5))
* **demo:** clarify the demo-recordings PR comment is a re-recording, not new content (Refs [#367](https://github.com/manhcuongdtbk/electric-water-management/issues/367)) ([94e8cc1](https://github.com/manhcuongdtbk/electric-water-management/commit/94e8cc1ee252e8e099d15531cad20485fc8f8d11))
* **demo:** gate demo artifact + comment on demo-relevant paths only (Refs [#367](https://github.com/manhcuongdtbk/electric-water-management/issues/367)) ([#370](https://github.com/manhcuongdtbk/electric-water-management/issues/370)) ([9a51ff0](https://github.com/manhcuongdtbk/electric-water-management/commit/9a51ff017856c09f95552e0586a00256fdb24bff))
* **demo:** lock demo spec into design-time DoD for customer-facing work ([#371](https://github.com/manhcuongdtbk/electric-water-management/issues/371)) ([44fd9cf](https://github.com/manhcuongdtbk/electric-water-management/commit/44fd9cf73225c845ef4b80fa8c6d18619591d6c4))
* **demo:** show the recalculated "Khác" result in the TN1 walkthrough (Refs [#363](https://github.com/manhcuongdtbk/electric-water-management/issues/363)) ([#375](https://github.com/manhcuongdtbk/electric-water-management/issues/375)) ([b4f5a01](https://github.com/manhcuongdtbk/electric-water-management/commit/b4f5a0102438d3fbf63911ce036ebbb6ead5ef38))
* **demo:** tighten TN1 — show cause→effect, trim narration, focus the role beat (Refs [#363](https://github.com/manhcuongdtbk/electric-water-management/issues/363)) ([#382](https://github.com/manhcuongdtbk/electric-water-management/issues/382)) ([54d9749](https://github.com/manhcuongdtbk/electric-water-management/commit/54d974926a7df1a66007a0f31f2930feceda36bf))
* guardrail against duplicate ADR numbers + clean up existing dups ([#348](https://github.com/manhcuongdtbk/electric-water-management/issues/348)) ([236c27b](https://github.com/manhcuongdtbk/electric-water-management/commit/236c27bbcf9ca73c3d7a46af1b0924ea1d83a7a8))


### Miscellaneous Chores

* add hook to block SendUserFile for video files ([#423](https://github.com/manhcuongdtbk/electric-water-management/issues/423)) ([01c1279](https://github.com/manhcuongdtbk/electric-water-management/commit/01c12793ea5781b2cd3ce86bc04b25c138d31ae4))
* **demo:** remove redundant smoke demo spec ([#372](https://github.com/manhcuongdtbk/electric-water-management/issues/372)) ([c94acbb](https://github.com/manhcuongdtbk/electric-water-management/commit/c94acbbab17c41dfc307046c4ae2e80521630298))
* **deps:** Bump concurrent-ruby from 1.3.6 to 1.3.7 ([#414](https://github.com/manhcuongdtbk/electric-water-management/issues/414)) ([0f27fe1](https://github.com/manhcuongdtbk/electric-water-management/commit/0f27fe15b6d9df96a5d58280226756a815fa40dc))
* **deps:** Bump net-imap from 0.6.4 to 0.6.4.1 ([#309](https://github.com/manhcuongdtbk/electric-water-management/issues/309)) ([fc86052](https://github.com/manhcuongdtbk/electric-water-management/commit/fc860521144c199dee2b7f99adde5bb7210231a3))
* **deps:** Bump nokogiri from 1.19.3 to 1.19.4 ([#413](https://github.com/manhcuongdtbk/electric-water-management/issues/413)) ([30f1f57](https://github.com/manhcuongdtbk/electric-water-management/commit/30f1f576b650b58851331be1c580ef46ee8d08da))
* **deps:** Bump the ruby-minor-patch group with 3 updates ([#398](https://github.com/manhcuongdtbk/electric-water-management/issues/398)) ([75bd186](https://github.com/manhcuongdtbk/electric-water-management/commit/75bd1869565a72fb17b23c4c27747d4601027104))
* **docker:** add demo subcommand to run demo specs locally ([#394](https://github.com/manhcuongdtbk/electric-water-management/issues/394)) ([c1182db](https://github.com/manhcuongdtbk/electric-water-management/commit/c1182db14c81f9b12cf16ad6a7181d80b44cbb20))
* update role count 6→7 and improve seed output ([#424](https://github.com/manhcuongdtbk/electric-water-management/issues/424)) ([#425](https://github.com/manhcuongdtbk/electric-water-management/issues/425)) ([cf5c060](https://github.com/manhcuongdtbk/electric-water-management/commit/cf5c060fa7fb61bedd4d1a4a00f36d36127b1b3d))

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
