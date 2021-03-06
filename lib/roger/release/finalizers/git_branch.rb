require "tmpdir"

module Roger::Release::Finalizers
  # Finalizes the release into a specific branch of a repository and pushes it
  class GitBranch < Roger::Release::Finalizers::Base
    self.name = :git_branch

    # @param Hash options The options
    #
    # @option options String :remote The remote repository (default is the
    #   origin of the current repository)
    # @option options String :branch The remote branch (default is "gh-pages")
    # @option options Boolean :cleanup Cleanup temp dir afterwards (default is
    #   true)
    # @option options Boolean :push Push to remote (default is true)
    def default_options
      {
        remote: nil,
        branch: "gh-pages",
        cleanup: true,
        push: true
      }
    end

    def perform
      remote = find_git_remote(release.project.path)
      branch = @options[:branch]

      tmp_dir = Pathname.new(::Dir.mktmpdir)
      clone_dir = tmp_dir + "clone"

      # Check if remote already has branch
      if remote_has_branch?(remote, branch)
        release.log(self, "Cloning existing repo")
        clone_branch(clone_dir, remote, branch)
      else
        release.log(self, "Creating empty branch")
        create_empty_branch(clone_dir, remote, branch)
      end

      @release.log(self, "Working git magic in #{clone_dir}")

      commit_and_push_release(clone_dir, branch)

      if @options[:cleanup]
        FileUtils.rm_rf(tmp_dir)
      else
        tmp_dir
      end
    end

    protected

    def commit_and_push_release(clone_dir, branch)
      ::Dir.chdir(clone_dir) do
        # 3. Copy changes
        FileUtils.rm_rf("*")
        FileUtils.cp_r @release.build_path.to_s + "/.", clone_dir.to_s

        commands = [
          %w(git add .), # 4. Add all files
          %w(git commit -q -a -m) << "Release #{@release.scm.version}" # 5. Commit
        ]

        # 6. Git push if in options
        commands << (%w(git push origin) << branch) if @options[:push]

        commands.each do |command|
          `#{Shellwords.join(command)}`
        end
      end
    end

    # Check if remote already has branch
    def remote_has_branch?(remote, branch)
      command = Shellwords.join([
                                  "git",
                                  "ls-remote",
                                  "--heads",
                                  remote,
                                  "refs/heads/#{branch}"
                                ])
      `#{command}` != ""
    end

    def create_empty_branch(clone_dir, remote, branch)
      commands = [
        %w(git init -q),
        %w(git remote add origin) << remote,
        %w(git checkout -q -b) << branch
      ]

      # Branch does not exist yet
      FileUtils.mkdir(clone_dir)
      ::Dir.chdir(clone_dir) do
        commands.each do |command|
          `#{Shellwords.join(command)}`
        end
      end
    end

    def clone_branch(clone_dir, remote, branch)
      command = Shellwords.join([
                                  "git",
                                  "clone",
                                  remote,
                                  "--branch",
                                  branch,
                                  "--single-branch",
                                  clone_dir
                                ])
      `#{command}`
    end

    def find_git_remote(path)
      if @options[:remote]
        remote = @options[:remote]
      else
        git_dir = Roger::Release::Scm::Git.find_git_dir(path)
        remote = `git --git-dir=#{Shellwords.escape(git_dir.to_s)} config --get remote.origin.url`
      end

      remote.strip!

      raise "No remote found for origin" if remote.nil? || remote.empty?

      remote
    end
  end
end

Roger::Release::Finalizers.register(Roger::Release::Finalizers::GitBranch)
