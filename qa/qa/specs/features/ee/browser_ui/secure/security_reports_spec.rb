# frozen_string_literal: true

require 'pathname'

module QA
  context 'Secure', :docker do
    let(:number_of_dependencies_in_fixture) { 1309 }
    let(:total_vuln_count) { 12 }
    let(:dependency_scan_vuln_count) { 4 }
    let(:dependency_scan_example_vuln) { 'jQuery before 3.4.0' }
    let(:container_scan_vuln_count) { 8 }
    let(:container_scan_example_vuln) { 'CVE-2017-18269 in glibc' }

    describe 'Security Reports' do
      after do
        Service::Runner.new(@executor).remove!
      end

      before do
        @executor = "qa-runner-#{Time.now.to_i}"

        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.perform(&:sign_in_using_credentials)

        @project = Resource::Project.fabricate_via_api! do |p|
          p.name = Runtime::Env.auto_devops_project_name || 'project-with-secure'
          p.description = 'Project with Secure'
        end

        Resource::Runner.fabricate! do |runner|
          runner.project = @project
          runner.name = @executor
          runner.tags = %w[qa test]
        end

        # Push fixture to generate Secure reports
        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = @project
          push.directory = Pathname
            .new(__dir__)
            .join('../../../../../ee/fixtures/secure_premade_reports')
          push.commit_message = 'Create Secure compatible application to serve premade reports'
        end

        Page::Project::Menu.perform(&:click_ci_cd_pipelines)
        Page::Project::Pipeline::Index.perform(&:click_on_latest_pipeline)

        wait_for_job "dependency_scanning"
      end

      it 'displays security reports in the pipeline' do
        Page::Project::Menu.perform(&:click_ci_cd_pipelines)
        Page::Project::Pipeline::Index.perform(&:click_on_latest_pipeline)

        Page::Project::Pipeline::Show.perform do |pipeline|
          pipeline.click_on_security

          filter_report_and_perform(pipeline, "Dependency Scanning") do
            expect(pipeline).to have_vulnerability_count_of dependency_scan_vuln_count
            expect(pipeline).to have_content dependency_scan_example_vuln
          end

          filter_report_and_perform(pipeline, "Container Scanning") do
            expect(pipeline).to have_vulnerability_count_of container_scan_vuln_count
            expect(pipeline).to have_content container_scan_example_vuln
          end
        end
      end

      it 'displays security reports in the project security dashboard' do
        Page::Project::Menu.perform(&:click_project)
        Page::Project::Menu.perform(&:click_on_security_dashboard)

        EE::Page::Project::Secure::Show.perform do |dashboard|
          filter_report_and_perform(dashboard, "Dependency Scanning") do
            expect(dashboard).to have_low_vulnerability_count_of 1
          end

          filter_report_and_perform(dashboard, "Container Scanning") do
            expect(dashboard).to have_low_vulnerability_count_of 2
          end
        end
      end

      it 'displays security reports in the group security dashboard' do
        Page::Main::Menu.perform(&:go_to_groups)
        Page::Dashboard::Groups.perform do |page|
          page.click_group @project.group.path
        end
        EE::Page::Group::Menu.perform(&:click_group_security_link)

        EE::Page::Group::Secure::Show.perform do |dashboard|
          dashboard.filter_project(@project.name)

          filter_report_and_perform(dashboard, "Dependency Scanning") do
            expect(dashboard).to have_content dependency_scan_example_vuln
          end

          filter_report_and_perform(dashboard, "Container Scanning") do
            expect(dashboard).to have_content container_scan_example_vuln
          end
        end
      end

      it 'displays the Dependency List' do
        Page::Project::Menu.perform(&:click_on_dependency_list)

        EE::Page::Project::Secure::DependencyList.perform do |page|
          expect(page).to have_dependency_count_of number_of_dependencies_in_fixture
        end
      end
    end

    def wait_for_job(job_name)
      Page::Project::Pipeline::Show.perform do |pipeline|
        pipeline.click_job(job_name)
      end
      Page::Project::Job::Show.perform do |job|
        expect(job).to be_successful(timeout: 600)
      end
    end

    def filter_report_and_perform(page, report)
      page.filter_report_type report
      yield
      page.filter_report_type report # Disable filter to avoid combining
    end
  end
end
