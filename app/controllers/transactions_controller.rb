class TransactionsController < ApplicationController
	def create
		begin
			to_user = User.find_by(CPF: params[:to_CPF])
			raise RangoLivreExceptions::NotFound if to_user.nil?
			from_user = @user
			check_if_enough_funds(from_user)

			params.permit(:account_type)
			from_transaction = Transaction.new(create_transaction_params)
			to_transaction = Transaction.new(amount: params[:amount], account_type: params[:account_type], transaction_type: 0, to_CPF: params[:to_CPF], scheduled: params[:scheduled], timestamp: params[:timestamp], from_CPF: @user[:CPF])
			
			Transaction.transaction do
				from_transaction[:account_type] = 0
				from_transaction[:responsible_id] = from_user[:id]
				from_transaction[:from_CPF] = from_user[:CPF]
				from_transaction[:transaction_type] = 1
				to_transaction[:responsible_id] = to_user[:id]
				to_transaction[:scheduled] = params[:scheduled]
				to_transaction[:timestamp] = params[:timestamp]
				to_transaction[:from_CPF] = from_user[:CPF]

				raise RangoLivreExceptions::BadParameters if (!to_transaction.valid?) || (params[:scheduled] == "true" && params[:timestamp].nil?)
				from_user.update(regular_balance: @user[:regular_balance] - params[:amount].to_f) if params[:scheduled] != "true" || params[:scheduled] != true
				if (params[:account_type]).to_i == 0 && params[:scheduled] == false
					to_user.update(regular_balance: to_user[:regular_balance] + params[:amount].to_f)
				elsif (params[:account_type]).to_i == 1 && params[:scheduled] == false
					to_user.update(meal_allowance_balance: to_user[:meal_allowance_balance] + params[:amount].to_f)
				end
				to_transaction.save!
				from_transaction.save!
			end
			
			render json: {transaction: from_transaction.json_object, regular_balance: @user[:regular_balance]}, status: 201
		rescue RangoLivreExceptions::NotFound
			render json: { error: 'User not found' }, status: 404
		rescue RangoLivreExceptions::CreateConflict
			render json: { error: "Not enough funds" }, status: 409
		rescue RangoLivreExceptions::BadParameters
			render json: { error: 'Bad parameters'}, status: 422
		rescue RangoLivreExceptions::UnauthorizedOperation
			render json: { error: 'Unauthorized token' }
		rescue => e
			Rails.logger.error e.message
			Rails.logger.error e.backtrace.join("\n")
		end
	end
	def index
		begin
			raise RangoLivreExceptions::BadParameters if (params[:offset].nil? || params[:limit].nil?)

			transactions = Transaction.where(to_CPF: @user[:CPF])
			total = transactions.count
			transactions = transactions.offset(offset).limit(limit)

			transactions = transactions.each {|x| x.json_object}

			render json: {
				transactions: transactions, 
				total: total,
				limit: limit,
				offset: offset
			}
		rescue RangoLivreExceptions::BadParameters
			render json: { error: 'Bad parameters'}, status: 422
		rescue => e
			Rails.logger.error e.message
			Rails.logger.error e.backtrace.join("\n")
		end	
	end
	def destroy
		begin
			transaction = Transaction.find_by(uuid: params[:id])			

			raise RangoLivreExceptions::NotFound if transaction.nil?
			raise RangoLivreExceptions::Forbidden if (transaction[:from_CPF] != @user[:CPF]) || transaction[:timestamp] >= Time.now.to_i

			transaction.destroy

			render status: 204
		rescue RangoLivreExceptions::Forbidden
			render json: {error: "Forbidden"}, status: 403
		rescue RangoLivreExceptions::NotFound
			render json: {error: "Not found"}, status: 404
		rescue => e
			Rails.logger.error e.message
			Rails.logger.error e.backtrace.join("\n")
		end
	end

	private
	
	def check_if_enough_funds(user)
		if !(user[:regular_balance] >= params[:amount])
			raise RangoLivreExceptions::CreateConflict
		end
	end
	
	def create_transaction_params
		params.permit(:amount, :to_CPF, :scheduled, :timestamp)
	end
	
    
end