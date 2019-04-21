require "logfiction/version"
require 'time'
require 'csv'

module Logfiction
  class FileTypeError < StandardError; end

  SESSION_OUT_MIN_TIME = 30 * 60 # sec (30 min)
  USER_ACTION_INTERVAL = [1, 120] # lowwer to upper(sec)

  attr_accessor :users, :items, :states, :transions, :assumptions, :access_log

  class AccessLog
    def initialize(assumptions={})
      @users = []
      @items = []
      @states = []
      @start_state = []
      @transitions = []
      @auto_transiton = {}
      @assumptions = {}
      @access_log = {}
      # access_log: user_id & seuquence of states
      # ex.) {user_id1(int):
      #         [{timestamp: timestamp(str),
      #          state_id: state_id(int),
      #          item [item(int), ...]}, ...], ...}

      # set assumption
      set_assumptions(assumptions)
    end

    # Set assumptions
    #   assumptions: object(hash)
    #     time_access_from(str): from what time generate logs
    #     user_n_sessions(int): how many sessions in day
    #     user_max_states(int): how many states in session
    #     n_users(int): how many users
    #     n_items(int): how many items
    def set_assumptions(assumptions={})
      @assumptions = {
        time_access_from: Time.parse("2018-06-29 09:00:00"),
        user_max_sessions: 5,
        user_max_actions: 100,
        n_users: 100,
        n_items: 100
      }
      if assumptions != {}
        # [TODO] validate assumptions
        assumptions.each do |key, value|
          @assumptions[key] = value
        end
      end
    end

    # User generater
    #   Input: n_users(int), users(hash)
    #   Ouptput: array of user_info
    #              user_info(hash): {user_id: user_id(int), options}
    def generate_users(n_users=100, users=[])
      if users.size == 0
        user_ids = (0..n_users - 1).to_a
        @users = user_ids.map{|user_id| { user_id: user_id } }
      else
        # [TODO] validate input data
        @users = users
      end
    end

    # Item generater
    #   Input: n_items(int), items(hash)
    #   Ouptput: object of array
    #              item(object): { item_id: item_id, options}
    def generate_items(n_items=100, items=[])
      if items.size == 0
        item_ids = (0..n_items - 1).to_a
        @items = item_ids.map{|item_id| { item_id: item_id } }
      else
        # [TODO] validate input data
        @items = items
      end
    end

    # States generater
    #   Input: state_transtion(object)
    #   Output: nill
    def generate_state_transiton(state_transtion={})
      if state_transtion == {}
        # default setting is like EC
        states = [
          {state_id: 0, state_name: 'top_page_view', item_type: :no_item, request: '/'},
          {state_id: 1, state_name: 'list_page_view', item_type: :many, request: '/list'},
          {state_id: 2, state_name: 'detail_page_view', item_type: :one, request: '/item'},
          {state_id: 3, state_name: 'item_purchase', item_type: :one, request: '/purchace'}
        ]
        
        start_state = [0]

        taranstion = [
          # probability is 0.6 if user transit from top(id:0) to list(id:1) page.
          # transition restrict by item is none.
          {from: 0, to: 1, probability: 0.6, dependent_item: false},

          # probability is 0.4 if user transit from list(id:1) to detail(id:2) page
          # "to state" item should be choosed "from state" items.
          {from: 1, to: 2, probability: 0.4, dependent_item: true},
      
          # probability is 0.2 if user transit from detatil(id:2) to purchase(id:3) page
          # "to state" item should be choosed "from state" items.
          # after transition to state '3', automatically transition to state "0"
          {from: 2, to: 3, probability: 0.2, dependent_item: true, auto_transiton: 0}
        ]
        @start_state, @transitions = start_state, taranstion
      else
        @start_state = state_transtion[:start_state]
        @transitions = state_transtion[:transitions]
        states = state_transtion[:states]
      end
      # convert states
      states_hash = {}
      states.each do |state|
        states_hash[state[:state_id]] = state
      end
      @states = states_hash

      # generate auto transiton
      @transitions.each do |transition|
        if transition[:auto_transiton]
          @auto_transiton[transition[:to]] = transition[:auto_transiton]
        end
      end
    end

    # generate state with items
    #   Input: items
    #   Output: items
    def get_next_items(from_state_id, to_state_id, current_items)
      unless from_state_id
        to_item_type = @states[to_state_id]
        
        unless to_item_type
          return []
        end
        
        to_item_type = [:item_type]
        if to_item_type == 'many'
          item_list = @items.each_slice(10).to_a
          pick_index = rand(item_list.size)
          return item_list[pick_index]
        elsif to_item_type == 'one'
          pick_index = rand(@items.size)
          return [@items[pick_index]]
        else
          return []
        end
      else
        from_item_type = @states[from_state_id][:item_type]
        
        to_state = @states[to_state_id]
        unless to_state
          return []
        end
        to_item_type = to_state[:item_type]

        dependent_item = false
        @transitions.each do |transiton|
          # normal transition
          dependent_item = true if transiton[:from] == from_state_id && transiton[:to] == to_state_id

          # back transition
          dependent_item = true if transiton[:from] == to_state_id && transiton[:to] == from_state_id
        end
        
        unless dependent_item
          return []
        end

        # no_item -> many
        if from_item_type == :no_item && to_item_type == :many
          item_list = @items.each_slice(10).to_a
          pick_index = rand(item_list.size)
          return item_list[pick_index]

        # many -> one
        elsif from_item_type == :many && to_item_type == :one
          pick_index = rand(current_items.size)
          return [current_items[pick_index]]

        # one -> many
        elsif from_item_type == :one && to_item_type == :many
          next_items = []
          item_list = @items.each_slice(10).to_a
          item_list.each_with_index do |items, i|
            if items.include?(current_items[0])
              next_items = items
            end
          end
          return next_items

        # one -> one
        elsif from_item_type == :one && to_item_type == :one
          return current_items

        else
          return []
        end
      end
    end

    # randam choice from states, which has a different probability
    # [TODO] more logically correct sampling
    #   Input: states_with_probability(Array of state_with_probability(Hash))
    #     state_id(int): probability(int)
    #   Output: state_id(int)
    def choice_next_state(states_with_probability)
      # transrate probability to number of trials
      n_trials = 100
      total = states_with_probability.values.inject(:+) * n_trials
      pick = rand(total)
      currentStack = 0
      states_with_probability.each do |state_id, probability|
        if (pick <= currentStack + probability * n_trials)
          return state_id
        else
          currentStack += probability * n_trials
        end
      end
      return states_with_probability.keys.sample
    end

    # random walk update user state
    #   Input:
    #     current_states(Hash):
    #       before_state(Hash):
    #         state_id(int): state_id
    #         item(Array): item list
    #       states_sequence(Array): states sequence list
    def update_user_state(user_id)
      next_state_interval = USER_ACTION_INTERVAL[0] + rand * USER_ACTION_INTERVAL[1]
      states_sequence = @access_log[user_id] || []

      # first action
      if states_sequence == []
        @access_log[user_id] = []
        next_state_id = @start_state.sample
        next_timestamp = @assumptions[:time_access_from] + next_state_interval
        next_items = []
      else
        from_state = states_sequence.last

        # check auto transiton
        auto_transiton_state = @auto_transiton[from_state[:state_id]]
        unless auto_transiton_state == nil
          next_state_id = auto_transiton_state
          next_timestamp = from_state[:timestamp] + 1
        else

          # new session
          unless states_sequence.last[:state_id]
            next_state_id = @start_state.sample
            next_timestamp = from_state[:timestamp] + (next_state_interval + SESSION_OUT_MIN_TIME)
          else

            # pickup possible transition states
            possible_transition_states = []

            # add state from transition_states
            total_probability = 0
            @transitions.each do |transition|
              if transition[:from] == from_state[:state_id]
                possible_transition_states << {state_id: transition[:to], probability: transition[:probability]}
                total_probability += transition[:probability]
              end
            end

            # add state back and exit
            # exclude auto transion
            back_state_id = states_sequence.last(2)[0][:state_id]
            if states_sequence.size == 1 || @auto_transiton.keys.include?(back_state_id)
              # exit only
              possible_transition_states << {state_id: false, probability: 1 - total_probability}
            else
              exit_probability = (1 - total_probability) * 0.3
              back_probability = (1 - total_probability) * 0.7

              # exit and back
              possible_transition_states << {state_id: false, probability: exit_probability}
              possible_transition_states << {state_id: back_state_id, probability: back_probability}

            end

            # choice next state
            state_probability_hash = possible_transition_states.map {|sp| {sp[:state_id] => sp[:probability]} }.reduce(&:merge)
            next_state_id = choice_next_state(state_probability_hash)
            next_timestamp = from_state[:timestamp] + next_state_interval
          end
        end

        from_state_id = from_state[:state_id]
        from_statre_items = from_state[:items]
        next_items = self.get_next_items(from_state_id, next_state_id, from_statre_items)
      end

      log = {
        timestamp: next_timestamp,
        state_id: next_state_id,
        items: next_items
      }

      @access_log[user_id] << log

      # return n_actions and n_sessions
      n_actions = @access_log[user_id].size
      n_sessions = 0
      @access_log[user_id].each do |state|
        n_sessions += 1 unless state[:state_id]
      end

      return n_actions, n_sessions
    end

    # Output:
    #   n_actions(int): total number of user's actions
    #   n_sessions: total number of user's sessions
    def generate_accesslog(n, output_form={})
      # add row number because of "false" log is not counted
      if n < 5000
        n_max = n * 2
      else
        n_max = n + (n/4)
      end
      # initialize access_log
      @access_log = {}

      # set default value unless another manual settting done
      if @transitions.size == 0
        self.generate_state_transiton()
      end
      
      if @users.size == 0
        self.generate_users(n_users=100, users=[])
      end

      if @items.size == 0
        self.generate_items(n_items=100, items=[])
      end

      n_row = 1
      while n_row < n_max
        # only one time update each users in second loop 
        @users.each do |user|
          user_id = user[:user_id]
          n_actions = 0
          n_sessions = 0
          user_max_sessions = @assumptions[:user_max_sessions]
          user_max_actions = @assumptions[:user_max_actions]
          while n_actions < user_max_actions && n_sessions < user_max_sessions
            n_actions, n_sessions = self.update_user_state(user_id)
            n_row += 1
            break if n_row > n_max
          end
          break if n_row > n_max
        end
        break if n_row > n_max
      end
      self.output_accesslog(n, output_form)
    end

    def output_accesslog(n_max, output_form)
      # default settings
      output_form = {
        basic_log: [:timestamp, :user_id, :state_id, :items],
        state: [:state_name],
        user: []
      }
      if output_form != {}
        output_form.each do |key, value|
          output_form[key] = value
        end
      end

      output_accesslogs = []
      @access_log.each do |user_id, logs|
        logs.each do |log|
          if log[:state_id]
            output_accesslog = {}

            # basic_log
            output_form[:basic_log].each do |log_item|
              if log_item == :items
                output_accesslog[log_item] = log[log_item].map{|e| e[:item_id] }.join(":")
              elsif log_item == :user_id
                output_accesslog[log_item] = user_id
              else
                output_accesslog[log_item] = log[log_item]
              end
            end

            # states
            output_form[:state].each do |log_item|
              output_accesslog[log_item] = @states[log[:state_id]][log_item]
            end

            # users
            output_form[:user].each do |log_item|
              output_accesslog[log_item] = @users[log[:state_id]][log_item]
            end

            output_accesslogs << output_accesslog
          end
        end
      end
      output_accesslogs.sort{|a, b| a[:timestamp] <=> b[:timestamp]}[0,n_max]
    end

    def export_logfile(n=10000, filetype='CSV', filepath='./fiction_log.csv')
      logs = self.generate_accesslog(n)
      headers = logs.first.keys
      if filetype == 'CSV'
        CSV.open(filepath, "wb") do |output|
          output.puts headers
          logs.each do |log|
            output.puts headers.map{|key| log[key]}
          end
        end
      else
        #[TODO] support output type (json, tsv, ...)
        raise FileTypeError, "Your input file type is not support..."
      end
    end
  end
end
