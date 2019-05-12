<app>
	<navbar player={ player } room={ room }></navbar>

  <div class="container">
  	<div class="row">
  		<div class="col">

				<div if={ room }>
					<h1>Room: { room.id }</h1><button class="btn btn-secondary" type="button" onclick={ toggle }>TOGGLE</button>
					<div if={ currentBoard == 'round' } class="row">
						<div class="col-2 badge badge-primary">ROUND: { round }</div>
            <div class="col-2 badge badge-sm badge-warning">Target Bid: { targetBid } <i class="fas fa-coins"></i></div>
            <div class="col-2" if={ currentBoard == 'round' } id="pieTimer"><pieTimer></pieTimer></div>
						<!-- <span class="badge badge-primary">ROUND: { round }</span>
						<span class="badge badge-sm badge-warning">Target Bid: { targetBid } <i class="fas fa-coins"></i></span>
						<span  if={ currentBoard == 'round' } id="pieTimer"><pieTimer></pieTimer></span> -->
					</div>

					<div class="table">
						<div if={ currentBoard == 'start' && roomPlayers.length == 4 } class="clock">
							<timer></timer>
						</div>
						<div if={ currentBoard == 'round' }>
							<!-- here need to grab data from database to show the highest and second highest players-->
							<span>{ highestBidder }</span><span>{ highestBid }</span>
							<span>{ secondHighestBidder }</span><span>{ secondHighestBid }</span>
						</div>
						<div id="winnerBoard" if={ currentBoard == 'winner' }>
							<i class="fas fa-crown"></i>
							<div><img id="winnerImg" src={ player.photoURL }></div>
							<div>{ player.displayName }</div>
						</div>
						<div id="rankBoard" if={ currentBoard == 'rank' }>
							<p id="rank">Rank</p>
							<div each={ roomPlayer in roomPlayers }>
								<img id="rankImg" src={ roomPlayer.photo }>
								<span><strong>{ roomPlayer.name }</strong></span>
								<span class="badge badge-info">{ roomPlayer.balance }</span>
							</div>
						</div>
					</div>
					<div if={ currentBoard !== 'rank'} each={ roomPlayer in roomPlayers }>
					<!-- <span if={ currentBoard == 'round'} class="badge badge-info"><i class="fas fa-hand-holding-usd"></i>{  here should be every bid that each player make }</span>-->
						<strong>{ roomPlayer.name }</strong>:
						<input id="bidInput" class="mr-sm-2" type="number" onchange={ saveInput } ref="bidInput" placeholder="Enter integer please" show={ currentBoard == 'round' && roomPlayer.name == this.player.displayName }>
						<button class="btn btn-sm btn-success" type="button" onclick={ bid } show={ currentBoard == 'round' && roomPlayer.name == this.player.displayName }>BID</button>
						<span class="badge badge-info" show={ roomPlayer.name == this.player.displayName }>BALANCE : {roomPlayer.balance}</span>
					</div>
				</div>
  		</div>
  	</div>
  </div>

  <script>
    // JAVASCRIPT
		let roomsRef = database.collection('player-rooms');

		this.room = null;
		this.roomPlayers = [];
		this.currentBoard = 'start';
		this.countNum = "";
		this.round = 1;
		this.targetBid = (Math.floor(Math.random() * 10 + 1)) * 10;
		this.bids = [];


		firebase.auth().onAuthStateChanged(playerObj => {
			if (playerObj) {
				this.player = playerObj;
			} else {
				this.player = null;
				this.room = null;
			}
			this.update();
		});

		let stopListening;

		observer.on('exitRoom', () => {
			let roomPlayerRef = database.collection('player-rooms').doc(this.room.id).collection('players').doc(this.player.uid);
			roomPlayerRef.delete().then(() => {
				this.room = null;
				this.update();
			});
		});

		observer.on('codeEntered', roomCode => {
			roomsRef.doc(roomCode).get().then(doc => {
				if (!doc.exists) {

					let room = {
						author: this.player.displayName,
						authorID: this.player.uid,
						id: doc.id,
						round: this.round,
						targetBid: this.targetBid,
						bids: this.bids
					}

					doc.ref.set(room);
					this.room = room;

				} else {
					let room = doc.data();
					this.room = room;
				}
				this.update();

				return doc;

			}).then(doc => {
				let roomPlayersRef = doc.ref.collection('players');

				roomPlayersRef.doc(this.player.uid).set({
					id: this.player.uid,
					name: this.player.displayName,
					photo: this.player.photoURL,
					balance: 50
				});
				return roomPlayersRef;

			}).then(roomPlayersRef => {
				roomPlayersRef.onSnapshot(querySnapshot => {
					this.roomPlayers = [];
					querySnapshot.forEach(doc => {
						this.roomPlayers.push(doc.data());
 					});
					this.update();
				});

				//when the number of players in one room reaches 4, it will trigger the timer
				let roomRef = roomsRef.doc(roomCode).collection('players');
				roomRef.get().then(querySnapshot => {
					if (querySnapshot.docs.length = 4) {
						observer.trigger('timer:start');
					}
				});


        let bidValue;
				saveInput(event) {
					bidValue = parseInt(event.target.value);
					if(bidValue < this.highestBid) {
						alert("You should bid higher");
					}
				}

				bid(event) {
					//bidTimer starts to count down
					//observer.trigger('bid:start');

					//grab data from the players' input
					let bidder = event.item.roomPlayer.name;
					let bidsRef = roomsRef.doc(roomCode);

					//every time a user makes a bid value, it will be saved to the field 'bids' in database
					bidsRef.update({
						bids: firebase.firestore.FieldValue.arrayUnion({name: bidder, bidValue: bidValue})
					});
				}

				roomsRef.doc(roomCode).onSnapshot(queryDocumentSnapshot => {
					//get bids array data from database
					let bidsArr = queryDocumentSnapshot.data().bids;
					//order data from database(reference to the lodash documentation: https://lodash.com/docs/4.17.11#orderBy
					let highestBidObjects = _.orderBy(bidsArr, ['bidValue'], ['desc']);
					// console.log(highestBidObjects);
					observer.trigger('bid:start');
					if (highestBidObjects.length >= 2){
						this.highestBid = parseInt(highestBidObjects[0].bidValue);
						this.highestBidder = highestBidObjects[0].name;
						this.secondHighestBid = parseInt(highestBidObjects[1].bidValue);
						this.secondHighestBidder = highestBidObjects[1].name;
					} else if(highestBidObjects.length == 1){
						this.highestBid = parseInt(highestBidObjects[0].bidValue);
						this.highestBidder = highestBidObjects[0].name;
					}else {
						this.highestBid = 0
					  this.highestBidder = ''
					  this.secondHighestBid = 0
					  this.secondHighestBidder = '';
					}
					this.update();
				});
			});
		});

		recalculateScores() {
			let roomref = database.collection('player-rooms').doc(this.room.id)
			let roomPlayerRef = roomref.collection('players').doc(this.player.uid);
			roomPlayerRef.get().then(querySnapshot => {
				console.log(querySnapshot)
				this.player.balance = querySnapshot.data().balance
				if (this.player.displayName == this.highestBidder){
					this.player.balance = this.player.balance + this.targetBid - this.highestBid
				} else if(this.player.displayName == this.secondHighestBidder){
					this.player.balance = this.player.balance - this.secondHighestBid
				};

				roomPlayerRef.set({
					balance: this.player.balance
				}, {merge: true});

				console.log(this.player);
				roomref.update({
					bids: []
				});
				this.targetBid = (Math.floor(Math.random() * 10 + 1)) * 10;
				this.update();
			});



		}

		//a function to toggle between start page and round page; only for coding process; delete it after finishing the whole project
		toggle() {
			if(this.currentBoard == 'start') {
				this.currentBoard = 'round';
			} else if(this.currentBoard == 'round') {
				this.currentBoard = 'winner';
			} else if(this.currentBoard == 'winner') {
				this.currentBoard = 'rank';
			} else if(this.currentBoard == 'rank') {
				this.currentBoard = 'start';
			}
		}

  </script>

  <style>
    /* CSS */
    :scope {}
		.table {
			width: 600px;
			height: 300px;
			background-color: #f8f9fa;
			text-align: center;
		}
		.clock {
			width: 200px;
			height: 200px;
			background-color: #fff;
			margin: auto;
		}
		#countNum {
			font-size: 100px;
		}
		#bidInput {
			width: 20%;
			border-radius: 30px;
		}
		#winnerBoard {
			padding-top: 50px;
			font-size: 50px;
		}
		#winnerImg {
			width: 60px;
		}
		#rankBoard {
			text-align: center;
			margin-top: 20px;
		}
		#rank {
			font-size: 45px;
			background-color: #4682b4;
		}
		#rankImg {
			width: 30px;

		}

  </style>
</app>
